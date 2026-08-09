from dataclasses import dataclass
from typing import Any

from bridge.notifications import NotificationService


@dataclass
class Sent:
    id: str


class FakeTeams:
    def __init__(self) -> None:
        self.calls: list[tuple[str, ...]] = []

    async def send(self, conversation_id: str, activity: str) -> Sent:
        self.calls.append(("send", conversation_id, activity))
        return Sent("root-1")

    async def reply(self, conversation_id: str, message_id: str, activity: str) -> Sent:
        self.calls.append(("reply", conversation_id, message_id, activity))
        return Sent("reply-1")


class FakeState:
    def __init__(self) -> None:
        self.saved: dict[str, str] | None = None

    async def get_channel(self) -> dict[str, Any]:
        return {
            "ConversationId": "conversation-1",
            "ServiceUrl": "https://smba.trafficmanager.net/teams/",
            "TeamId": "team-1",
            "ChannelId": "channel-1",
        }

    async def get_investigation(self, thread_id: str) -> dict[str, Any]:
        assert thread_id == "sre-1"
        return {
            "ConversationId": "conversation-1",
            "RootActivityId": "root-1",
            "TeamId": "team-1",
            "ChannelId": "channel-1",
        }

    async def save_investigation(self, request: dict[str, str]) -> None:
        self.saved = request


async def test_posts_and_replies_in_fixed_conversation() -> None:
    teams = FakeTeams()
    state = FakeState()
    service = NotificationService(teams, state)

    posted = await service.post_update("sre-1", "Investigation started")
    replied = await service.reply_update("sre-1", "Root cause found")

    assert posted == {"thread_id": "sre-1", "teams_activity_id": "root-1"}
    assert replied == {"thread_id": "sre-1", "teams_activity_id": "reply-1"}
    assert teams.calls == [
        ("send", "conversation-1", "Investigation started"),
        ("reply", "conversation-1", "root-1", "Root cause found"),
    ]
    assert state.saved is not None
    assert state.saved["channel_id"] == "channel-1"