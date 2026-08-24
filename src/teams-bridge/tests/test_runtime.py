from typing import Any

import httpx
from mcp import Client

from bridge.config import Settings
from bridge.github_continuation import (
    ContinuationResult,
    InvalidGitHubSignature,
)
from bridge.github_events import IgnoredGitHubEvent
from bridge.runtime import BridgeRuntime, SharedKeyMiddleware


def settings() -> Settings:
    return Settings(
        bot_client_id="00000000-0000-0000-0000-000000000001",
        bot_client_secret="test-only",
        bot_tenant_id="tenant-1",
        allowed_user_object_id="user-1",
        teams_tenant_id="tenant-1",
        teams_team_id="team-1",
        teams_channel_id="channel-1",
        storage_account_name="teststorage",
        storage_table_name="teamsbridge",
        sre_agent_endpoint="https://agent.example",
        mcp_shared_key="test-key",
        github_webhook_secret="webhook-secret",
        github_repository="msftse/sre-agent-demo",
        azure_subscription_id="subscription-1",
    )


async def test_exposes_only_three_notification_tools() -> None:
    runtime = BridgeRuntime(settings())

    async with Client(runtime.mcp) as client:
        result = await client.list_tools()

    tools = {tool.name: tool for tool in result.tools}
    assert sorted(tools) == [
        "get_incident_thread",
        "post_incident_update",
        "reply_incident_thread",
    ]
    assert set(tools["post_incident_update"].input_schema["properties"]) == {
        "incident_id",
        "message",
    }
    assert set(tools["get_incident_thread"].input_schema["properties"]) == {
        "incident_id"
    }


async def test_shared_key_middleware_rejects_missing_key() -> None:
    called = False
    sent: list[dict[str, Any]] = []

    async def downstream(scope: Any, receive: Any, send: Any) -> None:
        del scope, receive, send
        nonlocal called
        called = True

    async def receive() -> dict[str, Any]:
        return {"type": "http.request", "body": b""}

    async def send(message: dict[str, Any]) -> None:
        sent.append(message)

    middleware = SharedKeyMiddleware(downstream, "test-key")
    await middleware({"type": "http", "headers": []}, receive, send)

    assert not called
    assert sent[0]["status"] == 401


async def test_shared_key_middleware_allows_matching_key() -> None:
    called = False

    async def downstream(scope: Any, receive: Any, send: Any) -> None:
        del scope, receive, send
        nonlocal called
        called = True

    async def receive() -> dict[str, Any]:
        return {"type": "http.request", "body": b""}

    async def send(message: dict[str, Any]) -> None:
        del message

    middleware = SharedKeyMiddleware(downstream, "test-key")
    await middleware(
        {"type": "http", "headers": [(b"x-mcp-key", b"test-key")]},
        receive,
        send,
    )

    assert called


class FakeContinuation:
    def __init__(self, outcome: ContinuationResult | Exception) -> None:
        self.outcome = outcome

    async def accept(self, **_: Any) -> ContinuationResult:
        if isinstance(self.outcome, Exception):
            raise self.outcome
        return self.outcome


async def test_github_route_returns_processed_result() -> None:
    starts: list[tuple[str, str, dict[str, Any]]] = []

    async def start(
        function_name: str,
        instance_id: str,
        payload: dict[str, Any],
    ) -> str:
        starts.append((function_name, instance_id, payload))
        return instance_id

    runtime = BridgeRuntime(settings(), orchestration_starter=start)
    runtime.continuation = FakeContinuation(  # type: ignore[assignment]
        ContinuationResult(
            status="accepted",
            event_key="pull_request:opened:delivery-1",
            delivery={
                "delivery_id": "delivery-1",
                "event_type": "pull_request",
                "action": "opened",
                "repository": "msftse/sre-agent-demo",
                "sre_thread_id": "thread-1",
                "teams_thread_id": "alert-1",
                "pr_number": 42,
                "pr_url": "https://github.com/msftse/sre-agent-demo/pull/42",
                "head_sha": "head-1",
                "merge_sha": "",
                "conclusion": "",
            },
        )
    )
    transport = httpx.ASGITransport(app=runtime.web)

    async with httpx.AsyncClient(transport=transport, base_url="https://test") as client:
        response = await client.post("/api/github/events", content=b"{}")

    assert response.status_code == 202
    assert response.json()["status"] == "queued"
    assert starts[0][0] == "github_continuation_orchestrator"
    assert starts[0][1].startswith("github-continuation-")
    assert starts[0][2]["alert_resolution_timeout_minutes"] == 30


async def test_github_route_rejects_invalid_signature() -> None:
    runtime = BridgeRuntime(settings())
    runtime.continuation = FakeContinuation(  # type: ignore[assignment]
        InvalidGitHubSignature("signature")
    )
    transport = httpx.ASGITransport(app=runtime.web)

    async with httpx.AsyncClient(transport=transport, base_url="https://test") as client:
        response = await client.post("/api/github/events", content=b"{}")

    assert response.status_code == 401


async def test_github_route_ignores_out_of_scope_event() -> None:
    runtime = BridgeRuntime(settings())
    runtime.continuation = FakeContinuation(  # type: ignore[assignment]
        IgnoredGitHubEvent("event")
    )
    transport = httpx.ASGITransport(app=runtime.web)

    async with httpx.AsyncClient(transport=transport, base_url="https://test") as client:
        response = await client.post("/api/github/events", content=b"{}")

    assert response.status_code == 202
    assert response.json() == {"status": "ignored"}