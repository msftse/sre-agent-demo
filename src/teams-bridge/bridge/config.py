import os
from dataclasses import dataclass
from typing import Literal

PersonalChatAccessMode = Literal["allowed_user", "tenant"]


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
    teams_personal_chat_enabled: bool = False
    teams_personal_chat_access_mode: PersonalChatAccessMode = "allowed_user"
    teams_personal_chat_turns_per_hour: int = 10

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
        access_mode = os.getenv(
            "TEAMS_PERSONAL_CHAT_ACCESS_MODE", "allowed_user"
        ).casefold()
        if access_mode not in {"allowed_user", "tenant"}:
            raise RuntimeError(
                "TEAMS_PERSONAL_CHAT_ACCESS_MODE must be allowed_user or tenant."
            )
        try:
            turns_per_hour = int(os.getenv("TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR", "10"))
        except ValueError as error:
            raise RuntimeError(
                "TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR must be an integer."
            ) from error
        if turns_per_hour < 1 or turns_per_hour > 100:
            raise RuntimeError(
                "TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR must be between 1 and 100."
            )
        enabled = os.getenv("TEAMS_PERSONAL_CHAT_ENABLED", "false").casefold()
        if enabled not in {"true", "false"}:
            raise RuntimeError("TEAMS_PERSONAL_CHAT_ENABLED must be true or false.")
        return cls(
            **values,
            teams_personal_chat_enabled=enabled == "true",
            teams_personal_chat_access_mode=access_mode,  # type: ignore[arg-type]
            teams_personal_chat_turns_per_hour=turns_per_hour,
        )