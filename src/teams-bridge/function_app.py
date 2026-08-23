import json
import logging
from contextvars import ContextVar
from datetime import UTC, datetime, timedelta
from hashlib import sha256
from typing import Any, cast

import azure.durable_functions as durable
import azure.functions as func

from bridge.alert_management import (
    AlertManagementTemporaryError,
    AlertManagementTerminalError,
)
from bridge.boundary import BoundaryViolation
from bridge.chunking import chunk_text
from bridge.config import Settings
from bridge.runtime import BridgeRuntime

durable_client: ContextVar[durable.DurableOrchestrationClient | None] = ContextVar(
    "durable_client",
    default=None,
)


async def start_orchestration(
    function_name: str,
    instance_id: str,
    payload: dict[str, Any],
) -> str:
    client = durable_client.get()
    if client is None:
        raise RuntimeError("Durable client is unavailable for this request.")
    existing = await client.get_status(instance_id)
    if existing is not None:
        runtime_status = getattr(existing, "runtime_status", "")
        if runtime_status is not None:
            status_value = str(
                getattr(runtime_status, "value", runtime_status)
            ).casefold()
            if status_value and status_value not in {"failed", "terminated", "canceled"}:
                return instance_id
    return await client.start_new(
        orchestration_function_name=function_name,
        instance_id=instance_id,
        client_input=payload,
    )


settings = Settings.from_environment()
runtime = BridgeRuntime(settings, orchestration_starter=start_orchestration)
app = durable.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)
logger = logging.getLogger(__name__)


@runtime.teams.on_message
async def handle_teams_message(context: Any) -> None:
    activity = context.activity.model_dump(by_alias=True)
    try:
        request = runtime.boundary.require_allowed(activity)
    except BoundaryViolation as error:
        logger.warning(
            "teams_boundary_denied boundary=%s actual=%s allowed=%s",
            error.boundary,
            error.actual,
            error.allowed,
        )
        await context.reply("This Teams context is not authorized for the demo.")
        return

    command = request.text.strip()
    if command.casefold() == "status":
        if request.scope == "channel":
            await runtime.state.save_channel(request)
        await context.reply("Azure SRE Agent Teams bridge is ready.")
        return

    payload = request.to_dict()
    route_key = runtime.state.chat_route_key(payload)
    route = await runtime.state.get_chat_route(route_key)

    if request.scope == "personal" and command.casefold() == "/clear":
        if route is not None and route.get("Status") == "running":
            await context.reply("The current investigation is still running.")
            return
        await runtime.state.clear_chat_route(route_key)
        await context.reply("Personal SRE session cleared. Your next message starts fresh.")
        return

    force_new = False
    if request.scope == "personal" and command.casefold().startswith("/new"):
        if route is not None and route.get("Status") == "running":
            await context.reply("The current investigation is still running.")
            return
        await runtime.state.clear_chat_route(route_key)
        route = None
        force_new = True
        prompt = command[4:].strip()
        if not prompt:
            await context.reply("Personal SRE session reset. Send your next question.")
            return
        payload["text"] = prompt

    if not await runtime.state.claim_inbound_turn(request.activity_id):
        return

    if request.scope == "channel":
        create_new = route is None
    else:
        create_new = force_new or route is None
        if route is not None and route.get("Status") in {"running", "timed_out_running"}:
            await context.reply("The current investigation is still running.")
            return
        window = datetime.now(UTC).strftime("%Y%m%d%H")
        if not await runtime.state.claim_personal_rate(
            user_object_id=request.user_object_id,
            activity_id=request.activity_id,
            window=window,
            limit=settings.teams_personal_chat_turns_per_hour,
        ):
            await context.reply("Personal investigation limit reached. Try again later.")
            return

    if route is not None and str(route.get("UserObjectId", "")) != request.user_object_id:
        await context.reply("This Teams conversation is not authorized for that SRE thread.")
        return

    if request.scope == "channel" and route is not None:
        payload["root_activity_id"] = str(
            route.get("RootActivityId") or payload["root_activity_id"]
        )

    turn_id = sha256(request.activity_id.encode()).hexdigest()
    if not await runtime.state.claim_chat_turn(route_key, turn_id):
        await context.reply("The previous investigation turn is still running.")
        return

    try:
        if create_new:
            thread_id = await runtime.sre.start_thread(
                text=payload["text"],
                user_id=payload["user_object_id"],
                display_name=payload["user_display_name"],
            )
            watermark: frozenset[str] = frozenset()
        else:
            thread_id = str(route.get("SreThreadId", "")) if route else ""
            snapshot = await runtime.sre.get_thread_messages(thread_id=thread_id)
            watermark = snapshot.message_ids
            await runtime.sre.continue_thread(
                thread_id=thread_id,
                text=payload["text"],
                user_id=payload["user_object_id"],
                display_name=payload["user_display_name"],
            )
        await runtime.state.save_chat_route(
            payload,
            sre_thread_id=thread_id,
            status="running",
            message_watermark=json.dumps(sorted(watermark)),
        )
        turn_payload = {
            key: value
            for key, value in payload.items()
            if key != "text"
        } | {
            "route_key": route_key,
            "turn_id": turn_id,
            "sre_thread_id": thread_id,
            "created": "true" if create_new else "false",
            "message_ids": sorted(watermark),
        }
        client = durable_client.get()
        if client is None:
            raise RuntimeError("Durable client is unavailable for this request.")
        instance_id = await client.start_new(
            orchestration_function_name="teams_chat_turn_orchestrator",
            instance_id=turn_id,
            client_input=turn_payload,
        )
    except Exception:
        route = await runtime.state.get_chat_route(route_key)
        if route is not None:
            await runtime.state.update_chat_route_status(route_key, status="failed")
        await runtime.state.release_chat_turn(route_key, turn_id)
        raise
    await context.reply(f"Investigation queued. Tracking ID: `{instance_id}`")


@runtime.teams.on_conversation_update
async def handle_conversation_update(context: Any) -> None:
    request = runtime.boundary.require_allowed(
        context.activity.model_dump(by_alias=True),
        require_user=False,
    )
    if request.scope == "channel":
        await runtime.state.save_channel(request)


@app.route(
    route="{*route}",
    methods=["GET", "POST", "DELETE", "OPTIONS"],
)
@app.durable_client_input(client_name="client")
async def http_entrypoint(
    req: func.HttpRequest,
    context: func.Context,
    client: durable.DurableOrchestrationClient,
) -> func.HttpResponse:
    token = durable_client.set(client)
    try:
        await runtime.initialize()
        return await runtime.asgi.handle_async(req, context)
    finally:
        durable_client.reset(token)


@app.orchestration_trigger(context_name="context")
def teams_message_orchestrator(
    context: durable.DurableOrchestrationContext,
) -> dict[str, str]:
    request = context.get_input()
    persisted = yield context.call_activity("persist_teams_activity", request)
    investigation = yield context.call_activity("start_sre_investigation", persisted)
    result = yield context.call_activity("reply_with_sre_thread", investigation)
    return result


@app.orchestration_trigger(context_name="context")
def teams_chat_turn_orchestrator(
    context: durable.DurableOrchestrationContext,
) -> dict[str, str]:
    request = context.get_input()
    failure_request = request
    try:
        if request["created"] == "true":
            yield context.call_activity("reply_with_sre_thread", request)
        deadline = context.current_utc_datetime + timedelta(minutes=10)
        while context.current_utc_datetime < deadline:
            poll = yield context.call_activity("poll_sre_turn", request)
            if poll["state"] != "running":
                terminal_request = {**request, "terminal_state": poll["state"]}
                return (
                    yield context.call_activity("complete_sre_turn", terminal_request)
                )
            next_check = min(
                context.current_utc_datetime + timedelta(seconds=10), deadline
            )
            yield context.create_timer(next_check)
        return (yield context.call_activity("timeout_sre_turn", request))
    except Exception as error:
        failure_request["failure_type"] = type(error).__name__
        return (yield context.call_activity("fail_sre_turn", failure_request))


@app.orchestration_trigger(context_name="context")
def github_continuation_orchestrator(
    context: durable.DurableOrchestrationContext,
) -> dict[str, Any]:
    request = context.get_input()
    retry = durable.RetryOptions(
        first_retry_interval_in_milliseconds=5000,
        max_number_of_attempts=5,
    )
    result = yield context.call_activity_with_retry(
        "deliver_github_continuation",
        retry,
        request,
    )
    if result["start_alert_monitor"]:
        delivery = result["delivery"]
        monitor_request = {
            "alert_id": delivery["teams_thread_id"],
            "sre_thread_id": delivery["sre_thread_id"],
            "pr_number": delivery["pr_number"],
            "pr_url": delivery["pr_url"],
            "merge_sha": delivery["merge_sha"],
            "workflow_delivery_id": delivery["delivery_id"],
            "poll_seconds": request["alert_resolution_poll_seconds"],
            "timeout_minutes": request["alert_resolution_timeout_minutes"],
            "retry_minutes": request["alert_resolution_retry_minutes"],
        }
        result["alert_monitor"] = yield context.call_sub_orchestrator(
            "alert_resolution_orchestrator",
            monitor_request,
            instance_id=f"alert-resolution-{delivery['merge_sha']}",
        )
    return cast(dict[str, Any], result)


@app.orchestration_trigger(context_name="context")
def alert_resolution_orchestrator(
    context: durable.DurableOrchestrationContext,
) -> dict[str, str]:
    request = context.get_input()
    retry = durable.RetryOptions(
        first_retry_interval_in_milliseconds=5000,
        max_number_of_attempts=5,
    )
    primary_deadline = context.current_utc_datetime + timedelta(
        minutes=int(request["timeout_minutes"])
    )
    final_deadline = primary_deadline + timedelta(minutes=int(request["retry_minutes"]))
    poll_seconds = int(request["poll_seconds"])

    while context.current_utc_datetime < final_deadline:
        status = yield context.call_activity("poll_alert_status", request)
        if status["state"] == "resolved":
            wake = yield context.call_activity_with_retry(
                "wake_sre_for_final_rca",
                retry,
                {**request, "outcome": "resolved"},
            )
            finalization_request = {
                **request,
                "message_ids": wake["message_ids"],
            }
            finalization_deadline = context.current_utc_datetime + timedelta(minutes=10)
            while context.current_utc_datetime < finalization_deadline:
                finalization = yield context.call_activity_with_retry(
                    "poll_sre_turn",
                    retry,
                    finalization_request,
                )
                if finalization["state"] == "complete":
                    return {
                        "status": "finalized",
                        "sre_thread_id": request["sre_thread_id"],
                    }
                if finalization["state"] != "running":
                    return (
                        yield context.call_activity_with_retry(
                            "wake_sre_for_final_rca",
                            retry,
                            {
                                **request,
                                "outcome": "sre_failed",
                                "failure_type": finalization["state"],
                            },
                        )
                    )
                next_finalization_check = min(
                    context.current_utc_datetime + timedelta(seconds=10),
                    finalization_deadline,
                )
                yield context.create_timer(next_finalization_check)
            return (
                yield context.call_activity_with_retry(
                    "wake_sre_for_final_rca",
                    retry,
                    {**request, "outcome": "sre_timeout"},
                )
            )
        if status["state"] == "terminal_error":
            return (
                yield context.call_activity_with_retry(
                    "wake_sre_for_final_rca",
                    retry,
                    {
                        **request,
                        "outcome": "terminal_error",
                        "failure_type": status["failure_type"],
                    },
                )
            )
        next_check = min(
            context.current_utc_datetime + timedelta(seconds=poll_seconds),
            final_deadline,
        )
        yield context.create_timer(next_check)

    return (
        yield context.call_activity_with_retry(
            "wake_sre_for_final_rca",
            retry,
            {**request, "outcome": "timeout"},
        )
    )


@app.activity_trigger(input_name="request")
async def deliver_github_continuation(request: Any) -> dict[str, Any]:
    await runtime.initialize_teams()
    result = await runtime.continuation.deliver(cast(dict[str, Any], request))
    return result.to_dict()


@app.activity_trigger(input_name="request")
async def poll_alert_status(request: Any) -> dict[str, str]:
    payload = cast(dict[str, Any], request)
    try:
        snapshot = await runtime.alerts.get_alert(str(payload["alert_id"]))
    except AlertManagementTemporaryError:
        return {"state": "temporary_error", "failure_type": "temporary"}
    except AlertManagementTerminalError as error:
        return {"state": "terminal_error", "failure_type": type(error).__name__}
    return {"state": snapshot.condition.casefold(), "failure_type": ""}


@app.activity_trigger(input_name="request")
async def wake_sre_for_final_rca(request: Any) -> dict[str, Any]:
    payload = cast(dict[str, Any], request)
    outcome = str(payload["outcome"])
    alert_id = str(payload["alert_id"])
    thread_id = str(payload["sre_thread_id"])
    if not alert_id or not thread_id:
        raise RuntimeError("Alert and SRE thread correlation are required.")
    if outcome == "resolved":
        snapshot = await runtime.sre.get_thread_messages(thread_id=thread_id)
        await runtime.sre.send_message(
            thread_id=thread_id,
            text=(
                "Trusted recovery continuation: the correlated Azure Monitor alert "
                f"{alert_id} now reports Resolved for release {payload['merge_sha']}. "
                f"The signed successful delivery workflow {payload['workflow_delivery_id']} "
                "proves the checked-in recovery Helm test passed HTTP 200 and exact totals "
                "29600 / 5920 / 0 / 23680. Independently verify the alert, deployed SHA and "
                "digest, healthy workloads, FIELD20 telemetry, and absence of post-rollout "
                "failures. If all evidence passes, render the canonical RCA once and publish "
                f"the identical body to existing PR #{payload['pr_number']} and the existing "
                "Teams incident thread. Do not create or modify another PR, merge, approve, "
                "dispatch, or deploy."
            ),
        )
        return {
            "status": "sre_woken",
            "sre_thread_id": thread_id,
            "message_ids": sorted(snapshot.message_ids),
        }

    if outcome == "timeout":
        detail = "The alert did not resolve during the 30-minute monitor and 10-minute extension."
    elif outcome == "terminal_error":
        detail = "Azure alert status could not be read with the configured correlation and access."
    else:
        detail = "The SRE Agent finalization turn did not complete successfully."
    await runtime.notifications.reply_update(
        alert_id,
        f"{detail} "
        "Check Azure Monitor manually and continue the existing SRE Agent thread "
        f"`{thread_id}`. No final RCA was published.",
    )
    return {"status": outcome, "sre_thread_id": thread_id}


@app.activity_trigger(input_name="request")
async def persist_teams_activity(request: Any) -> dict[str, str]:
    payload = cast(dict[str, str], request)
    await runtime.state.save_channel_dict(payload)
    return payload


@app.activity_trigger(input_name="request")
async def start_sre_investigation(request: Any) -> dict[str, str]:
    payload = cast(dict[str, str], request)
    thread_id = await runtime.sre.start_thread(
        text=payload["text"],
        user_id=payload["user_object_id"],
        display_name=payload["user_display_name"],
    )
    payload["sre_thread_id"] = thread_id
    await runtime.state.save_investigation(payload)
    return payload


@app.activity_trigger(input_name="request")
async def reply_with_sre_thread(request: Any) -> dict[str, str]:
    payload = cast(dict[str, str], request)
    thread_id = payload["sre_thread_id"]
    await _send_to_teams(
        payload,
        f"Azure SRE Agent investigation started. Thread ID: `{thread_id}`",
    )
    return {"sre_thread_id": thread_id, "teams_activity_id": payload["activity_id"]}


@app.activity_trigger(input_name="request")
async def poll_sre_turn(request: Any) -> dict[str, str]:
    payload = cast(dict[str, Any], request)
    snapshot = await runtime.sre.get_thread_messages(
        thread_id=str(payload["sre_thread_id"])
    )
    previous_ids = frozenset(str(value) for value in payload["message_ids"])
    return {"state": snapshot.state_after(previous_ids), "raw_state": snapshot.raw_state}


@app.activity_trigger(input_name="request")
async def complete_sre_turn(request: Any) -> dict[str, str]:
    payload = cast(dict[str, Any], request)
    thread_id = str(payload["sre_thread_id"])
    snapshot = await runtime.sre.get_thread_messages(thread_id=thread_id)
    previous_ids = frozenset(str(value) for value in payload["message_ids"])
    terminal_state = str(payload["terminal_state"])
    texts = snapshot.new_agent_text(previous_ids)
    if terminal_state == "complete":
        answer = "\n\n".join(texts) or "Investigation completed without a text answer."
    elif terminal_state == "pending_input":
        answer = "\n\n".join(texts) or "Azure SRE Agent requires more information."
    elif terminal_state == "approval_required":
        detail = "\n\n".join(texts)
        answer = (
            f"{detail}\n\n" if detail else ""
        ) + f"Approval is required in the SRE Agent portal. Thread ID: `{thread_id}`"
    else:
        answer = f"Azure SRE Agent ended with status `{terminal_state}`. Thread ID: `{thread_id}`"
    await _deliver_chunks(payload, answer)
    await runtime.state.update_chat_route_status(
        str(payload["route_key"]),
        status="idle" if terminal_state in {"complete", "pending_input"} else terminal_state,
        message_watermark=json.dumps(sorted(snapshot.message_ids)),
    )
    await runtime.state.release_chat_turn(
        str(payload["route_key"]), str(payload["turn_id"])
    )
    return {"sre_thread_id": thread_id, "status": terminal_state}


@app.activity_trigger(input_name="request")
async def timeout_sre_turn(request: Any) -> dict[str, str]:
    payload = cast(dict[str, Any], request)
    thread_id = str(payload["sre_thread_id"])
    await _deliver_chunks(
        payload,
        "The investigation is still running after 10 minutes. "
        f"Continue in the SRE Agent portal with thread ID: `{thread_id}`",
    )
    await runtime.state.update_chat_route_status(
        str(payload["route_key"]), status="timed_out_running"
    )
    await runtime.state.release_chat_turn(
        str(payload["route_key"]), str(payload["turn_id"])
    )
    return {"sre_thread_id": thread_id, "status": "timeout"}


@app.activity_trigger(input_name="request")
async def fail_sre_turn(request: Any) -> dict[str, str]:
    payload = cast(dict[str, Any], request)
    route_key = str(payload.get("route_key", ""))
    turn_id = str(payload.get("turn_id", ""))
    thread_id = str(payload.get("sre_thread_id", ""))
    if route_key and turn_id:
        failure_payload = {**payload, "turn_id": f"{turn_id}-failure"}
        try:
            try:
                await _deliver_chunks(
                    failure_payload,
                    "The investigation could not be completed. "
                    + (
                        f"SRE Agent thread ID: `{thread_id}`"
                        if thread_id
                        else "Try again later."
                    ),
                )
            except Exception:
                logger.exception("teams_failure_notification_delivery_failed")
            route = await runtime.state.get_chat_route(route_key)
            if route is not None:
                await runtime.state.update_chat_route_status(route_key, status="failed")
        finally:
            await runtime.state.release_chat_turn(route_key, turn_id)
    return {"sre_thread_id": thread_id, "status": "failed"}


async def _deliver_chunks(payload: dict[str, Any], text: str) -> None:
    turn_id = str(payload["turn_id"])
    sent_chunks = await runtime.state.get_sent_chunks(turn_id)
    for index, chunk in enumerate(chunk_text(text)):
        chunk_hash = sha256(chunk.encode()).hexdigest()
        if index in sent_chunks:
            if sent_chunks[index] != chunk_hash:
                raise RuntimeError("Stored Teams chunk hash does not match delivery.")
            continue
        sent = await _send_to_teams(payload, chunk)
        activity_id = str(getattr(sent, "id", ""))
        if not activity_id:
            raise RuntimeError("Teams did not return an activity ID.")
        await runtime.state.mark_chunk_sent(
            turn_id=turn_id,
            chunk_index=index,
            chunk_hash=chunk_hash,
            teams_activity_id=activity_id,
        )


async def _send_to_teams(payload: dict[str, Any], text: str) -> Any:
    await runtime.initialize_teams()
    conversation_id = str(payload["conversation_id"])
    if str(payload.get("scope", "channel")) == "channel":
        return await runtime.teams.reply(
            conversation_id.split(";messageid=", 1)[0],
            str(payload.get("root_activity_id") or payload["activity_id"]),
            text,
        )
    return await runtime.teams.send(conversation_id, text)