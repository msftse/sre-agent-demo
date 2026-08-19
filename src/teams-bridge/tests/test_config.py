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


def test_parses_personal_chat_policy(monkeypatch: pytest.MonkeyPatch) -> None:
    env = {
        "CLIENT_ID": "client",
        "CLIENT_SECRET": "secret",
        "TENANT_ID": "bot-tenant",
        "ALLOWED_USER_OBJECT_ID": "allowed-user",
        "TEAMS_TENANT_ID": "teams-tenant",
        "TEAMS_TEAM_ID": "team",
        "TEAMS_CHANNEL_ID": "channel",
        "STORAGE_ACCOUNT_NAME": "storage",
        "STORAGE_TABLE_NAME": "table",
        "SRE_AGENT_ENDPOINT": "https://agent.example/",
        "MCP_SHARED_KEY": "mcp-key",
        "GITHUB_WEBHOOK_SECRET": "webhook",
        "GITHUB_REPOSITORY": "owner/repository",
        "TEAMS_PERSONAL_CHAT_ENABLED": "true",
        "TEAMS_PERSONAL_CHAT_ACCESS_MODE": "tenant",
        "TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR": "12",
    }
    for key, value in env.items():
        monkeypatch.setenv(key, value)

    settings = Settings.from_environment()

    assert settings.teams_personal_chat_enabled is True
    assert settings.teams_personal_chat_access_mode == "tenant"
    assert settings.teams_personal_chat_turns_per_hour == 12


@pytest.mark.parametrize(
    ("name", "value", "message"),
    [
        ("TEAMS_PERSONAL_CHAT_ENABLED", "yes", "must be true or false"),
        ("TEAMS_PERSONAL_CHAT_ACCESS_MODE", "everyone", "allowed_user or tenant"),
        ("TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR", "0", "between 1 and 100"),
    ],
)
def test_rejects_invalid_personal_chat_policy(
    monkeypatch: pytest.MonkeyPatch,
    name: str,
    value: str,
    message: str,
) -> None:
    test_parses_personal_chat_policy(monkeypatch)
    monkeypatch.setenv(name, value)

    with pytest.raises(RuntimeError, match=message):
        Settings.from_environment()