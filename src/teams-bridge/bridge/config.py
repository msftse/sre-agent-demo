import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    bot_client_id: str
    bot_client_secret: str
    bot_tenant_id: str
    allowed_user_object_id: str
    teams_tenant_id: str
    teams_team_id: str
    teams_channel_id: str
    storage_account_name: str
    storage_table_name: str
    sre_agent_endpoint: str
    mcp_shared_key: str
    github_webhook_secret: str
    github_repository: str

    @classmethod
    def from_environment(cls) -> "Settings":
        values = {
            "bot_client_id": os.getenv("CLIENT_ID", ""),
            "bot_client_secret": os.getenv("CLIENT_SECRET", ""),
            "bot_tenant_id": os.getenv("TENANT_ID", ""),
            "allowed_user_object_id": os.getenv("ALLOWED_USER_OBJECT_ID", ""),
            "teams_tenant_id": os.getenv("TEAMS_TENANT_ID", ""),
            "teams_team_id": os.getenv("TEAMS_TEAM_ID", ""),
            "teams_channel_id": os.getenv("TEAMS_CHANNEL_ID", ""),
            "storage_account_name": os.getenv("STORAGE_ACCOUNT_NAME", ""),
            "storage_table_name": os.getenv("STORAGE_TABLE_NAME", "teamsbridge"),
            "sre_agent_endpoint": os.getenv("SRE_AGENT_ENDPOINT", "").rstrip("/"),
            "mcp_shared_key": os.getenv("MCP_SHARED_KEY", ""),
            "github_webhook_secret": os.getenv("GITHUB_WEBHOOK_SECRET", ""),
            "github_repository": os.getenv("GITHUB_REPOSITORY", ""),
        }
        missing = [name for name, value in values.items() if not value]
        if missing:
            raise RuntimeError(
                f"Missing required Teams bridge settings: {', '.join(sorted(missing))}"
            )
        return cls(**values)