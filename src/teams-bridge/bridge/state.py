from collections.abc import Mapping
from typing import Any

from azure.core.credentials_async import AsyncTokenCredential
from azure.data.tables import UpdateMode
from azure.data.tables.aio import TableClient
from azure.identity.aio import DefaultAzureCredential

from bridge.boundary import TeamsRequest


class BridgeState:
    def __init__(
        self,
        account_name: str,
        table_name: str,
        credential: AsyncTokenCredential | None = None,
    ) -> None:
        self.credential = credential or DefaultAzureCredential()
        self.table = TableClient(
            endpoint=f"https://{account_name}.table.core.windows.net",
            table_name=table_name,
            credential=self.credential,
        )

    async def save_channel(self, request: TeamsRequest) -> None:
        await self.save_channel_dict(request.to_dict())

    async def save_channel_dict(self, request: Mapping[str, str]) -> None:
        await self.table.upsert_entity(
            {
                "PartitionKey": "channel",
                "RowKey": "target",
                "ConversationId": request["conversation_id"],
                "ServiceUrl": request["service_url"],
                "TeamId": request["team_id"],
                "ChannelId": request["channel_id"],
            },
            mode=UpdateMode.MERGE,
        )

    async def save_investigation(self, request: Mapping[str, str]) -> None:
        await self.table.upsert_entity(
            {
                "PartitionKey": "investigation",
                "RowKey": request["sre_thread_id"],
                "ConversationId": request["conversation_id"],
                "RootActivityId": request["activity_id"],
                "ServiceUrl": request["service_url"],
                "TeamId": request["team_id"],
                "ChannelId": request["channel_id"],
            },
            mode=UpdateMode.MERGE,
        )

    async def get_channel(self) -> dict[str, Any]:
        entity = await self.table.get_entity("channel", "target")
        return dict(entity)

    async def get_investigation(self, thread_id: str) -> dict[str, Any]:
        entity = await self.table.get_entity("investigation", thread_id)
        return dict(entity)