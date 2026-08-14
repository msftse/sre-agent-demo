from collections.abc import Mapping
from typing import Any

from azure.core.credentials_async import AsyncTokenCredential
from azure.core.exceptions import ResourceExistsError
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
        teams_thread_id = request.get("teams_thread_id", request["sre_thread_id"])
        await self.table.upsert_entity(
            {
                "PartitionKey": "investigation",
                "RowKey": teams_thread_id,
                "SreThreadId": request["sre_thread_id"],
                "TeamsThreadId": teams_thread_id,
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

    async def save_pull_request(
        self,
        *,
        thread_id: str,
        teams_thread_id: str,
        pr_number: int,
        pr_url: str,
        head_sha: str,
        merge_sha: str = "",
    ) -> None:
        correlation = {
            "SreThreadId": thread_id,
            "TeamsThreadId": teams_thread_id,
            "PrNumber": pr_number,
            "PrUrl": pr_url,
            "HeadSha": head_sha,
            "MergeSha": merge_sha,
        }
        await self.table.upsert_entity(
            {
                "PartitionKey": "pull-request",
                "RowKey": str(pr_number),
                **correlation,
            },
            mode=UpdateMode.MERGE,
        )
        await self.table.upsert_entity(
            {
                "PartitionKey": "head-sha",
                "RowKey": head_sha,
                **correlation,
            },
            mode=UpdateMode.MERGE,
        )
        if merge_sha:
            await self.table.upsert_entity(
                {
                    "PartitionKey": "merge-sha",
                    "RowKey": merge_sha,
                    **correlation,
                },
                mode=UpdateMode.MERGE,
            )

    async def get_pull_request(self, pr_number: int) -> dict[str, Any]:
        entity = await self.table.get_entity("pull-request", str(pr_number))
        return dict(entity)

    async def get_merge_correlation(self, merge_sha: str) -> dict[str, Any]:
        entity = await self.table.get_entity("merge-sha", merge_sha)
        return dict(entity)

    async def get_head_correlation(self, head_sha: str) -> dict[str, Any]:
        entity = await self.table.get_entity("head-sha", head_sha)
        return dict(entity)

    async def claim_delivery(self, delivery_id: str) -> bool:
        try:
            await self.table.create_entity(
                {
                    "PartitionKey": "github-delivery",
                    "RowKey": delivery_id,
                }
            )
        except ResourceExistsError:
            return False
        return True

    async def get_delivery(self, delivery_id: str) -> dict[str, Any]:
        entity = await self.table.get_entity("github-delivery", delivery_id)
        return dict(entity)

    async def mark_delivery(
        self,
        delivery_id: str,
        *,
        teams_sent: bool | None = None,
        sre_sent: bool | None = None,
    ) -> None:
        values: dict[str, Any] = {
            "PartitionKey": "github-delivery",
            "RowKey": delivery_id,
        }
        if teams_sent is not None:
            values["TeamsSent"] = teams_sent
        if sre_sent is not None:
            values["SreSent"] = sre_sent
        await self.table.update_entity(values, mode=UpdateMode.MERGE)