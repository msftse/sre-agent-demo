from typing import Any

from mcp import Client

from bridge.config import Settings
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
    )


async def test_exposes_only_three_notification_tools() -> None:
    runtime = BridgeRuntime(settings())

    async with Client(runtime.mcp) as client:
        result = await client.list_tools()

    assert sorted(tool.name for tool in result.tools) == [
        "get_incident_thread",
        "post_incident_update",
        "reply_incident_thread",
    ]


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