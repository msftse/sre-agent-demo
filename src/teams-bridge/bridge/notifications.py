from typing import Any, Protocol


class StateReader(Protocol):
    async def get_channel(self) -> dict[str, Any]: ...

    async def get_investigation(self, thread_id: str) -> dict[str, Any]: ...

    async def save_investigation(self, request: dict[str, str]) -> None: ...


class TeamsSender(Protocol):
    async def send(self, conversation_id: str, activity: str) -> Any: ...

    async def reply(
        self,
        conversation_id: str,
        message_id: str,
        activity: str,
    ) -> Any: ...


class NotificationService:
    def __init__(self, teams: TeamsSender, state: StateReader) -> None:
        self.teams = teams
        self.state = state

    async def post_update(self, thread_id: str, message: str) -> dict[str, str]:
        channel = await self.state.get_channel()
        conversation_id = str(channel["ConversationId"]).split(";messageid=", 1)[0]
        sent = await self.teams.send(conversation_id, message)
        activity_id = str(getattr(sent, "id", ""))
        if not activity_id:
            raise RuntimeError("Teams did not return an activity ID.")
        await self.state.save_investigation(
            {
                "sre_thread_id": thread_id,
                "conversation_id": conversation_id,
                "activity_id": activity_id,
                "service_url": str(channel["ServiceUrl"]),
                "team_id": str(channel["TeamId"]),
                "channel_id": str(channel["ChannelId"]),
            }
        )
        return {"thread_id": thread_id, "teams_activity_id": activity_id}

    async def reply_update(self, thread_id: str, message: str) -> dict[str, str]:
        investigation = await self.state.get_investigation(thread_id)
        sent = await self.teams.reply(
            str(investigation["ConversationId"]),
            str(investigation["RootActivityId"]),
            message,
        )
        return {
            "thread_id": thread_id,
            "teams_activity_id": str(getattr(sent, "id", "")),
        }

    async def get_thread(self, thread_id: str) -> dict[str, str]:
        investigation = await self.state.get_investigation(thread_id)
        return {
            "thread_id": thread_id,
            "conversation_id": str(investigation["ConversationId"]),
            "root_activity_id": str(investigation["RootActivityId"]),
            "team_id": str(investigation["TeamId"]),
            "channel_id": str(investigation["ChannelId"]),
        }