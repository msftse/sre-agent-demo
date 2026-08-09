import re
from collections.abc import Mapping
from dataclasses import dataclass
from html import unescape
from typing import Any


class BoundaryViolation(ValueError):
    def __init__(self, boundary: str, actual: str, allowed: str) -> None:
        super().__init__(f"Teams {boundary} is not allowed.")
        self.boundary = boundary
        self.actual = actual
        self.allowed = allowed


@dataclass(frozen=True)
class TeamsRequest:
    activity_id: str
    conversation_id: str
    service_url: str
    tenant_id: str
    team_id: str
    channel_id: str
    user_object_id: str
    user_display_name: str
    text: str

    def to_dict(self) -> dict[str, str]:
        return {
            "activity_id": self.activity_id,
            "conversation_id": self.conversation_id,
            "service_url": self.service_url,
            "tenant_id": self.tenant_id,
            "team_id": self.team_id,
            "channel_id": self.channel_id,
            "user_object_id": self.user_object_id,
            "user_display_name": self.user_display_name,
            "text": self.text,
        }


def _mapping(value: Any) -> Mapping[str, Any]:
    return value if isinstance(value, Mapping) else {}


def _identifier(value: Any) -> str:
    if isinstance(value, str):
        return value
    return str(_mapping(value).get("id", ""))


def _message_text(value: Any) -> str:
    text = unescape(str(value or ""))
    return re.sub(r"<at>.*?</at>", "", text, flags=re.IGNORECASE).strip()


class TeamsBoundary:
    def __init__(
        self,
        *,
        tenant_id: str,
        team_id: str,
        channel_id: str,
        allowed_user_object_id: str,
    ) -> None:
        self.tenant_id = tenant_id
        self.team_id = team_id
        self.channel_id = channel_id
        self.allowed_user_object_id = allowed_user_object_id

    def require_allowed(
        self,
        activity: Mapping[str, Any],
        *,
        require_user: bool = True,
    ) -> TeamsRequest:
        channel_data = _mapping(activity.get("channelData"))
        tenant_id = _identifier(channel_data.get("tenant"))
        team = _mapping(channel_data.get("team"))
        team_id = str(team.get("aadGroupId", "")) or _identifier(team) or str(
            channel_data.get("teamsTeamId", "")
        )
        channel_id = _identifier(channel_data.get("channel")) or str(
            channel_data.get("teamsChannelId", "")
        )
        sender = _mapping(activity.get("from"))
        user_object_id = str(
            sender.get("aadObjectId", sender.get("aad_object_id", ""))
        )

        expected = {
            "tenant": (tenant_id, self.tenant_id),
            "team": (team_id, self.team_id),
            "channel": (channel_id, self.channel_id),
        }
        for boundary, (actual, allowed) in expected.items():
            if actual != allowed:
                raise BoundaryViolation(boundary, actual, allowed)
        if require_user and user_object_id != self.allowed_user_object_id:
            raise BoundaryViolation("user", user_object_id, self.allowed_user_object_id)

        conversation = _mapping(activity.get("conversation"))
        request = TeamsRequest(
            activity_id=str(activity.get("id", "")),
            conversation_id=str(conversation.get("id", "")),
            service_url=str(activity.get("serviceUrl", "")),
            tenant_id=tenant_id,
            team_id=team_id,
            channel_id=channel_id,
            user_object_id=user_object_id,
            user_display_name=str(sender.get("name", "Teams user")),
            text=_message_text(activity.get("text")),
        )
        required = [request.activity_id, request.conversation_id, request.service_url]
        if require_user:
            required.extend([request.user_object_id, request.text])
        if not all(required):
            raise BoundaryViolation("required-context", "missing", "present")
        return request