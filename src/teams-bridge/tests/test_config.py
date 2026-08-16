import pytest

from bridge.config import Settings


def test_from_environment_requires_github_repository(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    env = {
        "CLIENT_ID": "00000000-0000-0000-0000-000000000001",
        "CLIENT_SECRET": "test-secret",
        "TENANT_ID": "00000000-0000-0000-0000-000000000002",
        "ALLOWED_USER_OBJECT_ID": "00000000-0000-0000-0000-000000000003",
        "TEAMS_TENANT_ID": "00000000-0000-0000-0000-000000000004",
        "TEAMS_TEAM_ID": "00000000-0000-0000-0000-000000000005",
        "TEAMS_CHANNEL_ID": "19:test@thread.tacv2",
        "STORAGE_ACCOUNT_NAME": "teststorage",
        "STORAGE_TABLE_NAME": "teamsbridge",
        "SRE_AGENT_ENDPOINT": "https://agent.example",
        "MCP_SHARED_KEY": "mcp-shared-key",
        "GITHUB_WEBHOOK_SECRET": "webhook-secret",
    }
    for key, value in env.items():
        monkeypatch.setenv(key, value)

    # Ensure per-fork isolation: events are rejected when repository identity is missing.
    monkeypatch.delenv("GITHUB_REPOSITORY", raising=False)

    with pytest.raises(RuntimeError, match="github_repository"):
        Settings.from_environment()