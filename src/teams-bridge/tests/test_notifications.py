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
            "ConversationId": "conversation-1;messageid=old-thread-root",
            "ServiceUrl": "https://smba.trafficmanager.net/teams/",
            "TeamId": "team-1",
            "ChannelId": "channel-1",
        }

    async def get_investigation(self, thread_id: str) -> dict[str, Any]:
        assert thread_id == "incident-1"
        return {
            "SreThreadId": "sre-1",
            "ConversationId": "conversation-1",
            "RootActivityId": "root-1",
            "TeamId": "team-1",
            "ChannelId": "channel-1",
        }

    async def save_investigation(self, request: dict[str, str]) -> None:
        self.saved = request


class FakeSre:
    def __init__(self) -> None:
        self.incident_ids: list[str] = []

    async def find_thread_by_incident_id(self, incident_id: str) -> str:
        self.incident_ids.append(incident_id)
        assert incident_id == "incident-1"
        return "sre-1"


async def test_posts_and_replies_in_fixed_conversation() -> None:
    teams = FakeTeams()
    state = FakeState()
    sre = FakeSre()
    service = NotificationService(teams, state, sre)

    posted = await service.post_update("incident-1", "Investigation started")
    replied = await service.reply_update("incident-1", "Root cause found")
    thread = await service.get_thread("incident-1")

    assert posted == {
        "thread_id": "incident-1",
        "incident_id": "incident-1",
        "sre_thread_id": "sre-1",
        "teams_activity_id": "root-1",
    }
    assert replied == {
        "thread_id": "incident-1",
        "incident_id": "incident-1",
        "teams_activity_id": "reply-1",
    }
    assert thread == {
        "thread_id": "incident-1",
        "incident_id": "incident-1",
        "sre_thread_id": "sre-1",
        "conversation_id": "conversation-1",
        "root_activity_id": "root-1",
        "team_id": "team-1",
        "channel_id": "channel-1",
    }
    assert teams.calls == [
        ("send", "conversation-1", "Investigation started"),
        ("reply", "conversation-1", "root-1", "Root cause found"),
    ]
    assert state.saved is not None
    assert state.saved["channel_id"] == "channel-1"
    assert state.saved["sre_thread_id"] == "sre-1"
    assert state.saved["teams_thread_id"] == "incident-1"
    assert sre.incident_ids == ["incident-1"]


async def test_resolves_canonical_thread_for_legacy_incident_record() -> None:
    class LegacyState(FakeState):
        async def get_investigation(self, thread_id: str) -> dict[str, Any]:
            investigation = await super().get_investigation(thread_id)
            investigation.pop("SreThreadId")
            return investigation

    sre = FakeSre()
    service = NotificationService(FakeTeams(), LegacyState(), sre)

    thread = await service.get_thread("incident-1")

    assert thread["sre_thread_id"] == "sre-1"
    assert sre.incident_ids == ["incident-1"]