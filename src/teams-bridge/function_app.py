import logging
from contextvars import ContextVar
from typing import Any, cast

import azure.durable_functions as durable
import azure.functions as func

from bridge.boundary import BoundaryViolation
from bridge.config import Settings
from bridge.runtime import BridgeRuntime

settings = Settings.from_environment()
runtime = BridgeRuntime(settings)
durable_client: ContextVar[durable.DurableOrchestrationClient | None] = ContextVar(
    "durable_client",
    default=None,
)
app = durable.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)
logger = logging.getLogger(__name__)


@runtime.teams.on_message
async def handle_teams_message(context: Any) -> None:
    try:
        request = runtime.boundary.require_allowed(
            context.activity.model_dump(by_alias=True)
        )
    except BoundaryViolation as error:
        logger.warning(
            "teams_boundary_denied boundary=%s actual=%s allowed=%s",
            error.boundary,
            error.actual,
            error.allowed,
        )
        await context.reply("This Teams context is not authorized for the demo.")
        return

    if request.text.lower() == "status":
        await runtime.state.save_channel(request)
        await context.reply("Azure SRE Agent Teams bridge is ready.")
        return

    client = durable_client.get()
    if client is None:
        raise RuntimeError("Durable client is unavailable for this request.")

    instance_id = await client.start_new(
        orchestration_function_name="teams_message_orchestrator",
        client_input=request.to_dict(),
    )
    await context.reply(f"Investigation queued. Tracking ID: `{instance_id}`")


@runtime.teams.on_conversation_update
async def handle_conversation_update(context: Any) -> None:
    request = runtime.boundary.require_allowed(
        context.activity.model_dump(by_alias=True),
        require_user=False,
    )
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
    await runtime.teams.reply(
        payload["conversation_id"],
        payload["activity_id"],
        f"Azure SRE Agent investigation started. Thread ID: `{thread_id}`",
    )
    return {"sre_thread_id": thread_id, "teams_activity_id": payload["activity_id"]}