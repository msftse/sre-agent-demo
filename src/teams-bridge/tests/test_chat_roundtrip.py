import os
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from hashlib import sha256
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
}.items():
    os.environ.setdefault(name, value)

import function_app  # noqa: E402
from bridge.chunking import chunk_text  # noqa: E402
from bridge.sre_client import SreMessage, SreTurnSnapshot  # noqa: E402


@dataclass
class Sent:
    id: str


class FakeTeams:
    def __init__(self) -> None:
        self.calls: list[tuple[str, ...]] = []

    async def send(self, conversation_id: str, text: str) -> Sent:
        self.calls.append(("send", conversation_id, text))
        return Sent(f"sent-{len(self.calls)}")

    async def reply(self, conversation_id: str, root_id: str, text: str) -> Sent:
        self.calls.append(("reply", conversation_id, root_id, text))
        return Sent(f"sent-{len(self.calls)}")


class FakeState:
    def __init__(self) -> None:
        self.routes: list[dict[str, Any]] = []
        self.statuses: list[tuple[str, str]] = []
        self.released: list[tuple[str, str]] = []
        self.chunks: dict[int, str] = {}
        self.saved_channel = False
        self.route: dict[str, Any] | None = None
        self.cleared: list[str] = []
        self.claimed_inbound = True
        self.claimed_turn = True
        self.rate_allowed = True

    @staticmethod
    def chat_route_key(payload: dict[str, str]) -> str:
        return "route-1"

    async def get_chat_route(self, route_key: str) -> dict[str, Any] | None:
        return self.route

    async def clear_chat_route(self, route_key: str) -> bool:
        self.cleared.append(route_key)
        self.route = None
        return True

    async def claim_inbound_turn(self, activity_id: str) -> bool:
        return self.claimed_inbound

    async def claim_chat_turn(self, route_key: str, turn_id: str) -> bool:
        return self.claimed_turn

    async def claim_personal_rate(self, **values: object) -> bool:
        return self.rate_allowed

    async def save_channel_dict(self, payload: dict[str, str]) -> None:
        self.saved_channel = True

    async def save_chat_route(self, request: dict[str, str], **values: str) -> str:
        self.routes.append({**request, **values})
        return request["route_key"]

    async def get_sent_chunks(self, turn_id: str) -> dict[int, str]:
        return dict(self.chunks)

    async def mark_chunk_sent(
        self,
        *,
        turn_id: str,
        chunk_index: int,
        chunk_hash: str,
        teams_activity_id: str,
    ) -> None:
        self.chunks[chunk_index] = chunk_hash

    async def update_chat_route_status(
        self,
        route_key: str,
        *,
        status: str,
        message_watermark: str | None = None,
    ) -> None:
        self.statuses.append((route_key, status))

    async def release_chat_turn(self, route_key: str, turn_id: str) -> None:
        self.released.append((route_key, turn_id))

def snapshot(*messages: SreMessage, state: str = "Idle") -> SreTurnSnapshot:
    return SreTurnSnapshot(state="complete", raw_state=state, messages=messages)


class FakeSre:
    def __init__(self, snapshots: list[SreTurnSnapshot]) -> None:
        self.snapshots = snapshots
        self.started: list[tuple[str, str, str]] = []
        self.continued: list[tuple[str, str, str, str]] = []

    async def start_thread(self, *, text: str, user_id: str, display_name: str) -> str:
        self.started.append((text, user_id, display_name))
        return "sre-thread-1"

    async def continue_thread(
        self,
        *,
        thread_id: str,
        text: str,
        user_id: str,
        display_name: str,
    ) -> None:
        self.continued.append((thread_id, text, user_id, display_name))

    async def get_thread_messages(self, *, thread_id: str) -> SreTurnSnapshot:
        return self.snapshots.pop(0) if len(self.snapshots) > 1 else self.snapshots[0]


class FakeRuntime:
    def __init__(self, snapshots: list[SreTurnSnapshot]) -> None:
        self.state = FakeState()
        self.sre = FakeSre(snapshots)
        self.teams = FakeTeams()
        self.boundary: Any = None


def payload(scope: str = "channel", create_new: str = "true") -> dict[str, str]:
    return {
        "activity_id": "activity-1",
        "conversation_id": "conversation-1",
        "service_url": "https://smba.trafficmanager.net/teams/",
        "tenant_id": "tenant-1",
        "team_id": "team-1" if scope == "channel" else "",
        "channel_id": "channel-1" if scope == "channel" else "",
        "user_object_id": "user-1",
        "user_display_name": "Operator",
        "text": "check AKS",
        "scope": scope,
        "conversation_type": "channel" if scope == "channel" else "personal",
        "reply_to_id": "" if create_new == "true" else "root-1",
        "root_activity_id": "root-1" if scope == "channel" else "conversation-1",
        "route_key": "route-1",
        "turn_id": "turn-1",
        "sre_thread_id": "" if create_new == "true" else "sre-thread-1",
    }


async def test_delivers_completed_answer_to_channel_root(monkeypatch: Any) -> None:
    answer = SreMessage("new-1", "SREAgent", "AKS is healthy", "time", True, False, False)
    fake = FakeRuntime([snapshot(answer)])
    monkeypatch.setattr(function_app, "runtime", fake)
    request: dict[str, Any] = {
        **payload(),
        "sre_thread_id": "sre-thread-1",
        "message_ids": [],
        "terminal_state": "complete",
    }

    result = await function_app.complete_sre_turn(request)

    assert result["status"] == "complete"
    assert fake.teams.calls == [
        ("reply", "conversation-1", "root-1", "AKS is healthy")
    ]
    assert fake.state.statuses == [("route-1", "idle")]
    assert fake.state.released == [("route-1", "turn-1")]


async def test_delivers_completed_answer_to_personal_conversation(monkeypatch: Any) -> None:
    answer = SreMessage("new-1", "SREAgent", "AKS is healthy", "time", True, False, False)
    fake = FakeRuntime([snapshot(answer)])
    monkeypatch.setattr(function_app, "runtime", fake)
    request: dict[str, Any] = {
        **payload("personal"),
        "sre_thread_id": "sre-thread-1",
        "message_ids": [],
        "terminal_state": "complete",
    }

    await function_app.complete_sre_turn(request)

    assert fake.teams.calls == [("send", "conversation-1", "AKS is healthy")]


class FakeContext:
    def __init__(self) -> None:
        self.current_utc_datetime = datetime(2026, 8, 19, tzinfo=UTC)

    def get_input(self) -> dict[str, str]:
        return payload()

    def call_activity(self, name: str, value: object) -> tuple[str, str, object]:
        return ("activity", name, value)

    def create_timer(self, deadline: datetime) -> tuple[str, datetime]:
        return ("timer", deadline)


class Activity:
    def __init__(self, value: dict[str, object]) -> None:
        self.value = value

    def model_dump(self, **_: object) -> dict[str, object]:
        return self.value


class MessageContext:
    def __init__(self, value: dict[str, object]) -> None:
        self.activity = Activity(value)
        self.replies: list[str] = []

    async def reply(self, text: str) -> None:
        self.replies.append(text)


class Boundary:
    def __init__(self, request: Any) -> None:
        self.request = request

    def require_allowed(self, activity: dict[str, object]) -> Any:
        return self.request


class DurableClient:
    def __init__(self) -> None:
        self.calls: list[dict[str, Any]] = []

    async def start_new(self, **values: Any) -> str:
        self.calls.append(values)
        return str(values["instance_id"])


def orchestrator_function() -> Any:
    closure = function_app.teams_chat_turn_orchestrator._function._func.__closure__
    assert closure is not None
    return closure[0].cell_contents


def test_orchestrator_completes_after_poll() -> None:
    context = FakeContext()
    orchestrator = orchestrator_function()(context)

    turn: dict[str, Any] = {**payload(), "created": "true", "message_ids": []}
    context.get_input = lambda: turn  # type: ignore[method-assign]
    orchestrator = orchestrator_function()(context)
    assert next(orchestrator)[1] == "reply_with_sre_thread"
    assert orchestrator.send({})[1] == "poll_sre_turn"
    assert orchestrator.send({"state": "complete"})[1] == "complete_sre_turn"
    try:
        orchestrator.send({"status": "complete"})
    except StopIteration as stopped:
        assert stopped.value["status"] == "complete"
    else:
        raise AssertionError("orchestrator did not complete")


def test_orchestrator_uses_durable_timer_and_times_out() -> None:
    context = FakeContext()
    turn: dict[str, Any] = {**payload(), "created": "false", "message_ids": []}
    context.get_input = lambda: turn  # type: ignore[method-assign]
    orchestrator = orchestrator_function()(context)
    assert next(orchestrator)[1] == "poll_sre_turn"
    timer = orchestrator.send({"state": "running"})
    assert timer[0] == "timer"
    assert timer[1] == context.current_utc_datetime + timedelta(seconds=10)
    context.current_utc_datetime += timedelta(minutes=10)
    assert orchestrator.send(None)[1] == "timeout_sre_turn"


async def test_personal_status_is_side_effect_free(monkeypatch: Any) -> None:
    request = SimpleNamespace(**payload("personal"), to_dict=lambda: payload("personal"))
    request.text = "status"
    fake = FakeRuntime([snapshot()])
    fake.boundary = Boundary(request)
    monkeypatch.setattr(function_app, "runtime", fake)
    context = MessageContext({})

    await function_app.handle_teams_message(context)

    assert context.replies == ["Azure SRE Agent Teams bridge is ready."]
    assert fake.state.saved_channel is False


async def test_personal_message_dispatches_isolated_turn(monkeypatch: Any) -> None:
    values = payload("personal")
    request = SimpleNamespace(**values, to_dict=lambda: dict(values))
    fake = FakeRuntime([snapshot()])
    fake.boundary = Boundary(request)
    client = DurableClient()
    monkeypatch.setattr(function_app, "runtime", fake)
    monkeypatch.setattr(
        function_app,
        "settings",
        SimpleNamespace(teams_personal_chat_turns_per_hour=10),
    )
    token = function_app.durable_client.set(client)  # type: ignore[arg-type]
    context = MessageContext({})
    try:
        await function_app.handle_teams_message(context)
    finally:
        function_app.durable_client.reset(token)

    assert len(client.calls) == 1
    assert client.calls[0]["orchestration_function_name"] == (
        "teams_chat_turn_orchestrator"
    )
    assert client.calls[0]["client_input"]["created"] == "true"
    assert "text" not in client.calls[0]["client_input"]
    assert fake.sre.started == [("check AKS", "user-1", "Operator")]
    assert context.replies[0].startswith("Investigation queued.")


async def test_personal_follow_up_uses_watermark_without_prompt_history(
    monkeypatch: Any,
) -> None:
    values = payload("personal", "false")
    request = SimpleNamespace(**values, to_dict=lambda: dict(values))
    old = SreMessage("old-1", "SREAgent", "old", "time", True, False, False)
    fake = FakeRuntime([snapshot(old)])
    fake.boundary = Boundary(request)
    fake.state.route = {"Status": "idle", "SreThreadId": "sre-thread-1", "UserObjectId": "user-1"}
    client = DurableClient()
    monkeypatch.setattr(function_app, "runtime", fake)
    monkeypatch.setattr(
        function_app,
        "settings",
        SimpleNamespace(teams_personal_chat_turns_per_hour=10),
    )
    token = function_app.durable_client.set(client)  # type: ignore[arg-type]
    context = MessageContext({})
    try:
        await function_app.handle_teams_message(context)
    finally:
        function_app.durable_client.reset(token)

    assert fake.sre.continued == [
        ("sre-thread-1", "check AKS", "user-1", "Operator")
    ]
    assert client.calls[0]["client_input"]["message_ids"] == ["old-1"]
    assert "text" not in client.calls[0]["client_input"]


async def test_personal_clear_removes_only_personal_route(monkeypatch: Any) -> None:
    values = payload("personal")
    values["text"] = "/clear"
    request = SimpleNamespace(**values, to_dict=lambda: dict(values))
    fake = FakeRuntime([snapshot()])
    fake.boundary = Boundary(request)
    fake.state.route = {"Status": "idle"}
    monkeypatch.setattr(function_app, "runtime", fake)
    context = MessageContext({})

    await function_app.handle_teams_message(context)

    assert fake.state.cleared == ["route-1"]
    assert "cleared" in context.replies[0]


async def test_first_channel_mention_in_thread_starts_sre_route(
    monkeypatch: Any,
) -> None:
    values = payload("channel", "false")
    request = SimpleNamespace(**values, to_dict=lambda: dict(values))
    fake = FakeRuntime([snapshot()])
    fake.boundary = Boundary(request)
    client = DurableClient()
    monkeypatch.setattr(function_app, "runtime", fake)
    token = function_app.durable_client.set(client)  # type: ignore[arg-type]
    context = MessageContext({})
    try:
        await function_app.handle_teams_message(context)
    finally:
        function_app.durable_client.reset(token)

    assert fake.sre.started == [("check AKS", "user-1", "Operator")]
    assert fake.state.routes[0]["sre_thread_id"] == "sre-thread-1"
    assert client.calls[0]["client_input"]["created"] == "true"
    assert context.replies[0].startswith("Investigation queued.")


async def test_duplicate_inbound_activity_is_idempotent_noop(monkeypatch: Any) -> None:
    values = payload("personal")
    request = SimpleNamespace(**values, to_dict=lambda: dict(values))
    fake = FakeRuntime([snapshot()])
    fake.boundary = Boundary(request)
    fake.state.claimed_inbound = False
    monkeypatch.setattr(function_app, "runtime", fake)
    context = MessageContext({})

    await function_app.handle_teams_message(context)

    assert context.replies == []
    assert fake.sre.started == []


async def test_delivery_resumes_after_recorded_chunk(monkeypatch: Any) -> None:
    text = "paragraph\n\n" * 2000
    chunks = chunk_text(text)
    assert len(chunks) > 1
    answer = SreMessage("new-1", "SREAgent", text, "time", True, False, False)
    fake = FakeRuntime([snapshot(answer)])
    fake.state.chunks[0] = sha256(chunks[0].encode()).hexdigest()
    monkeypatch.setattr(function_app, "runtime", fake)
    request: dict[str, Any] = {
        **payload("personal"),
        "sre_thread_id": "sre-thread-1",
        "message_ids": [],
        "terminal_state": "complete",
    }

    await function_app.complete_sre_turn(request)

    assert [call[-1] for call in fake.teams.calls] == list(chunks[1:])


async def test_delivery_rejects_changed_recorded_chunk(monkeypatch: Any) -> None:
    answer = SreMessage("new-1", "SREAgent", "answer", "time", True, False, False)
    fake = FakeRuntime([snapshot(answer)])
    fake.state.chunks[0] = "different-hash"
    monkeypatch.setattr(function_app, "runtime", fake)
    request: dict[str, Any] = {
        **payload("personal"),
        "sre_thread_id": "sre-thread-1",
        "message_ids": [],
        "terminal_state": "complete",
    }

    with pytest.raises(RuntimeError, match="hash does not match"):
        await function_app.complete_sre_turn(request)

    assert fake.teams.calls == []