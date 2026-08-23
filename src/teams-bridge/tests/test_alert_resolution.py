import os
from dataclasses import dataclass
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any

import pytest

for name, value in {
    "CLIENT_ID": "client",
    "CLIENT_SECRET": "secret",
    "TENANT_ID": "bot-tenant",
    "ALLOWED_USER_OBJECT_ID": "allowed-user",
    "TEAMS_TENANT_ID": "teams-tenant",
    "TEAMS_TEAM_ID": "team",
    "TEAMS_CHANNEL_ID": "channel",
    "STORAGE_ACCOUNT_NAME": "storage",
    "STORAGE_TABLE_NAME": "table",
    "SRE_AGENT_ENDPOINT": "https://agent.example",
    "MCP_SHARED_KEY": "mcp-key",
    "GITHUB_WEBHOOK_SECRET": "webhook",
    "GITHUB_REPOSITORY": "owner/repository",
    "AZURE_SUBSCRIPTION_ID": "subscription-1",
}.items():
    os.environ.setdefault(name, value)

import function_app  # noqa: E402
from bridge.alert_management import (  # noqa: E402
    AlertManagementTemporaryError,
    AlertManagementTerminalError,
    AlertSnapshot,
)


class OrchestrationContext:
    def __init__(self, request: dict[str, Any]) -> None:
        self.request = request
        self.current_utc_datetime = datetime(2026, 8, 20, tzinfo=UTC)

    def get_input(self) -> dict[str, Any]:
        return self.request

    def call_activity(self, name: str, value: object) -> tuple[str, str, object]:
        return ("activity", name, value)

    def call_activity_with_retry(
        self,
        name: str,
        retry: object,
        value: object,
    ) -> tuple[str, str, object, object]:
        return ("activity_retry", name, retry, value)

    def call_sub_orchestrator(
        self,
        name: str,
        value: object,
        instance_id: str | None = None,
    ) -> tuple[str, str, object, str | None]:
        return ("sub_orchestrator", name, value, instance_id)

    def create_timer(self, deadline: datetime) -> tuple[str, datetime]:
        return ("timer", deadline)


def monitor_request() -> dict[str, Any]:
    return {
        "alert_id": "alert-1",
        "sre_thread_id": "thread-1",
        "pr_number": 42,
        "pr_url": "https://github.com/owner/repository/pull/42",
        "merge_sha": "merge-123",
        "workflow_delivery_id": "delivery-1",
        "poll_seconds": 30,
        "timeout_minutes": 30,
        "retry_minutes": 10,
    }


def complete(generator: Any, value: object) -> Any:
    with pytest.raises(StopIteration) as stopped:
        generator.send(value)
    return stopped.value.value


def orchestrator_function(wrapper: Any) -> Any:
    closure = wrapper._function._func.__closure__
    assert closure is not None
    return closure[0].cell_contents


def test_alert_monitor_wakes_sre_only_after_resolution() -> None:
    context = OrchestrationContext(monitor_request())
    generator = orchestrator_function(function_app.alert_resolution_orchestrator)(context)

    first = next(generator)
    assert first[:2] == ("activity", "poll_alert_status")

    wake = generator.send({"state": "resolved", "failure_type": ""})
    assert wake[:2] == ("activity_retry", "wake_sre_for_final_rca")
    assert wake[3]["outcome"] == "resolved"

    poll = generator.send({"status": "sre_woken", "message_ids": ["old-1"]})
    assert poll[:2] == ("activity_retry", "poll_sre_turn")
    assert poll[3]["message_ids"] == ["old-1"]
    assert complete(generator, {"state": "complete"}) == {
        "status": "finalized",
        "sre_thread_id": "thread-1",
    }


def test_alert_monitor_uses_primary_and_retry_windows_before_timeout() -> None:
    context = OrchestrationContext(monitor_request())
    generator = orchestrator_function(function_app.alert_resolution_orchestrator)(context)

    assert next(generator)[:2] == ("activity", "poll_alert_status")
    timer = generator.send({"state": "fired", "failure_type": ""})
    assert timer[0] == "timer"

    context.current_utc_datetime = datetime(2026, 8, 20, 0, 30, tzinfo=UTC)
    assert generator.send(None)[:2] == ("activity", "poll_alert_status")
    timer = generator.send({"state": "temporary_error", "failure_type": "temporary"})
    assert timer[0] == "timer"

    context.current_utc_datetime = datetime(2026, 8, 20, 0, 40, tzinfo=UTC)
    timeout = generator.send(None)
    assert timeout[:2] == ("activity_retry", "wake_sre_for_final_rca")
    assert timeout[3]["outcome"] == "timeout"
    assert complete(generator, {"status": "timeout"}) == {"status": "timeout"}


def test_alert_monitor_stops_on_terminal_error() -> None:
    context = OrchestrationContext(monitor_request())
    generator = orchestrator_function(function_app.alert_resolution_orchestrator)(context)

    next(generator)
    terminal = generator.send(
        {"state": "terminal_error", "failure_type": "AlertManagementTerminalError"}
    )

    assert terminal[:2] == ("activity_retry", "wake_sre_for_final_rca")
    assert terminal[3]["outcome"] == "terminal_error"
    assert complete(generator, {"status": "terminal_error"}) == {
        "status": "terminal_error"
    }


def test_alert_monitor_notifies_when_sre_finalization_fails() -> None:
    context = OrchestrationContext(monitor_request())
    generator = orchestrator_function(function_app.alert_resolution_orchestrator)(context)

    next(generator)
    generator.send({"state": "resolved", "failure_type": ""})
    poll = generator.send({"status": "sre_woken", "message_ids": ["old-1"]})
    assert poll[:2] == ("activity_retry", "poll_sre_turn")

    failed = generator.send({"state": "failed"})
    assert failed[:2] == ("activity_retry", "wake_sre_for_final_rca")
    assert failed[3]["outcome"] == "sre_failed"
    assert complete(generator, {"status": "sre_failed"}) == {
        "status": "sre_failed"
    }


def test_alert_monitor_times_out_sre_finalization_after_ten_minutes() -> None:
    context = OrchestrationContext(monitor_request())
    generator = orchestrator_function(function_app.alert_resolution_orchestrator)(context)

    next(generator)
    generator.send({"state": "resolved", "failure_type": ""})
    generator.send({"status": "sre_woken", "message_ids": ["old-1"]})
    timer = generator.send({"state": "running"})
    assert timer[0] == "timer"

    context.current_utc_datetime = datetime(2026, 8, 20, 0, 10, tzinfo=UTC)
    timed_out = generator.send(None)
    assert timed_out[:2] == ("activity_retry", "wake_sre_for_final_rca")
    assert timed_out[3]["outcome"] == "sre_timeout"
    assert complete(generator, {"status": "sre_timeout"}) == {
        "status": "sre_timeout"
    }


def test_github_orchestrator_starts_one_deterministic_alert_monitor() -> None:
    request = {
        **monitor_request(),
        "delivery_id": "delivery-1",
        "event_type": "workflow_run",
        "action": "completed",
        "repository": "owner/repository",
        "teams_thread_id": "alert-1",
        "head_sha": "merge-123",
        "conclusion": "success",
        "alert_resolution_poll_seconds": 30,
        "alert_resolution_timeout_minutes": 30,
        "alert_resolution_retry_minutes": 10,
    }
    context = OrchestrationContext(request)
    generator = orchestrator_function(function_app.github_continuation_orchestrator)(
        context
    )

    delivery = next(generator)
    assert delivery[:2] == ("activity_retry", "deliver_github_continuation")

    sub = generator.send(
        {
            "status": "processed",
            "event_key": "workflow_run:completed:delivery-1",
            "delivery": request,
            "start_alert_monitor": True,
        }
    )
    assert sub[:2] == ("sub_orchestrator", "alert_resolution_orchestrator")
    assert sub[3] == "alert-resolution-merge-123"

    result = complete(generator, {"status": "sre_woken"})
    assert result["alert_monitor"] == {"status": "sre_woken"}


@dataclass
class FakeAlerts:
    outcome: AlertSnapshot | Exception

    async def get_alert(self, alert_id: str) -> AlertSnapshot:
        assert alert_id == "alert-1"
        if isinstance(self.outcome, Exception):
            raise self.outcome
        return self.outcome


class FakeSre:
    def __init__(self) -> None:
        self.messages: list[tuple[str, str]] = []

    async def send_message(self, *, thread_id: str, text: str) -> None:
        self.messages.append((thread_id, text))

    async def get_thread_messages(self, *, thread_id: str) -> object:
        assert thread_id == "thread-1"
        return SimpleNamespace(message_ids=frozenset({"old-1"}))


class FakeNotifications:
    def __init__(self) -> None:
        self.messages: list[tuple[str, str]] = []

    async def reply_update(self, thread_id: str, message: str) -> dict[str, str]:
        self.messages.append((thread_id, message))
        return {"thread_id": thread_id, "teams_activity_id": "activity-1"}


@pytest.mark.parametrize(
    ("outcome", "expected"),
    [
        (AlertSnapshot("Fired", "Acknowledged"), "fired"),
        (AlertSnapshot("Resolved", "Acknowledged"), "resolved"),
        (AlertManagementTemporaryError("temporary"), "temporary_error"),
        (AlertManagementTerminalError("terminal"), "terminal_error"),
    ],
)
async def test_poll_alert_status_classifies_activity_outcome(
    monkeypatch: pytest.MonkeyPatch,
    outcome: AlertSnapshot | Exception,
    expected: str,
) -> None:
    fake = SimpleNamespace(alerts=FakeAlerts(outcome))
    monkeypatch.setattr(function_app, "runtime", fake)

    result = await function_app.poll_alert_status({"alert_id": "alert-1"})

    assert result["state"] == expected


async def test_resolved_alert_wakes_existing_sre_thread(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fake = SimpleNamespace(sre=FakeSre(), notifications=FakeNotifications())
    monkeypatch.setattr(function_app, "runtime", fake)
    request = {**monitor_request(), "outcome": "resolved"}

    result = await function_app.wake_sre_for_final_rca(request)

    assert result == {
        "status": "sre_woken",
        "sre_thread_id": "thread-1",
        "message_ids": ["old-1"],
    }
    assert fake.notifications.messages == []
    assert fake.sre.messages[0][0] == "thread-1"
    assert "existing PR #42" in fake.sre.messages[0][1]
    assert "existing Teams incident thread" in fake.sre.messages[0][1]


async def test_timeout_posts_manual_check_to_existing_teams_thread(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fake = SimpleNamespace(sre=FakeSre(), notifications=FakeNotifications())
    monkeypatch.setattr(function_app, "runtime", fake)
    request = {**monitor_request(), "outcome": "timeout"}

    result = await function_app.wake_sre_for_final_rca(request)

    assert result == {"status": "timeout", "sre_thread_id": "thread-1"}
    assert fake.sre.messages == []
    assert fake.notifications.messages[0][0] == "alert-1"
    assert "No final RCA was published" in fake.notifications.messages[0][1]


async def test_start_orchestration_reuses_running_instance(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class Client:
        started = False

        async def get_status(self, instance_id: str) -> object:
            assert instance_id == "instance-1"
            return SimpleNamespace(runtime_status="Running")

        async def start_new(self, **kwargs: object) -> str:
            self.started = True
            return str(kwargs["instance_id"])

    client = Client()
    token = function_app.durable_client.set(client)  # type: ignore[arg-type]
    try:
        result = await function_app.start_orchestration(
            "orchestrator",
            "instance-1",
            {"value": "safe"},
        )
    finally:
        function_app.durable_client.reset(token)

    assert result == "instance-1"
    assert client.started is False


async def test_start_orchestration_starts_when_status_object_is_empty() -> None:
    class Client:
        started = False

        async def get_status(self, instance_id: str) -> object:
            assert instance_id == "instance-1"
            return SimpleNamespace(runtime_status=None)

        async def start_new(self, **kwargs: object) -> str:
            self.started = True
            return str(kwargs["instance_id"])

    client = Client()
    token = function_app.durable_client.set(client)  # type: ignore[arg-type]
    try:
        result = await function_app.start_orchestration(
            "orchestrator",
            "instance-1",
            {"value": "safe"},
        )
    finally:
        function_app.durable_client.reset(token)

    assert result == "instance-1"
    assert client.started is True
