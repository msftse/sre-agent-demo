from collections.abc import Mapping
from hashlib import sha256
from typing import Any

from azure.core import MatchConditions
from azure.core.credentials_async import AsyncTokenCredential
from azure.core.exceptions import (
    ResourceExistsError,
    ResourceModifiedError,
    ResourceNotFoundError,
)
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

    @staticmethod
    def chat_route_key(request: Mapping[str, str]) -> str:
        if request["scope"] == "personal":
            identity = "|".join(
                (
                    "personal",
                    request["tenant_id"],
                    request["user_object_id"],
                    request["conversation_id"],
                )
            )
        else:
            identity = "|".join(
                (
                    "channel",
                    request["tenant_id"],
                    request["team_id"],
                    request["channel_id"],
                    request["conversation_id"],
                )
            )
        return sha256(identity.encode()).hexdigest()

    async def save_chat_route(
        self,
        request: Mapping[str, str],
        *,
        sre_thread_id: str,
        status: str,
        message_watermark: str = "",
    ) -> str:
        route_key = self.chat_route_key(request)
        await self.table.upsert_entity(
            {
                "PartitionKey": "teams-chat",
                "RowKey": route_key,
                "Scope": request["scope"],
                "TenantId": request["tenant_id"],
                "TeamId": request["team_id"],
                "ChannelId": request["channel_id"],
                "UserObjectId": request["user_object_id"],
                "ConversationId": request["conversation_id"],
                "RootActivityId": request["root_activity_id"],
                "ServiceUrl": request["service_url"],
                "SreThreadId": sre_thread_id,
                "Status": status,
                "MessageWatermark": message_watermark,
            },
            mode=UpdateMode.MERGE,
        )
        return route_key

    async def get_chat_route(self, route_key: str) -> dict[str, Any] | None:
        try:
            entity = await self.table.get_entity("teams-chat", route_key)
        except ResourceNotFoundError:
            return None
        return dict(entity)

    async def clear_chat_route(self, route_key: str) -> bool:
        try:
            await self.table.delete_entity("teams-chat", route_key)
        except ResourceNotFoundError:
            return False
        return True

    async def update_chat_route_status(
        self,
        route_key: str,
        *,
        status: str,
        message_watermark: str | None = None,
    ) -> None:
        values: dict[str, Any] = {
            "PartitionKey": "teams-chat",
            "RowKey": route_key,
            "Status": status,
        }
        if message_watermark is not None:
            values["MessageWatermark"] = message_watermark
        await self.table.update_entity(values, mode=UpdateMode.MERGE)

    async def claim_inbound_turn(self, activity_id: str) -> bool:
        try:
            await self.table.create_entity(
                {
                    "PartitionKey": "teams-inbound-turn",
                    "RowKey": sha256(activity_id.encode()).hexdigest(),
                }
            )
        except ResourceExistsError:
            return False
        return True

    async def claim_chat_turn(self, route_key: str, turn_id: str) -> bool:
        try:
            await self.table.create_entity(
                {
                    "PartitionKey": "teams-chat-lock",
                    "RowKey": route_key,
                    "TurnId": turn_id,
                }
            )
        except ResourceExistsError:
            return False
        return True

    async def release_chat_turn(self, route_key: str, turn_id: str) -> None:
        try:
            lock = await self.table.get_entity("teams-chat-lock", route_key)
        except ResourceNotFoundError:
            return
        if str(lock.get("TurnId", "")) != turn_id:
            return
        await self.table.delete_entity("teams-chat-lock", route_key)

    async def claim_personal_rate(
        self,
        *,
        user_object_id: str,
        activity_id: str,
        window: str,
        limit: int,
    ) -> bool:
        del activity_id
        user_hash = sha256(user_object_id.encode()).hexdigest()
        partition = "teams-personal-rate"
        row_key = sha256(f"{window}|{user_hash}".encode()).hexdigest()
        try:
            await self.table.create_entity(
                {
                    "PartitionKey": partition,
                    "RowKey": row_key,
                    "Count": 1,
                }
            )
            return True
        except ResourceExistsError:
            pass

        for _ in range(5):
            entity = await self.table.get_entity(partition, row_key)
            count = int(entity.get("Count", 0))
            if count >= limit:
                return False
            metadata = getattr(entity, "metadata", {})
            etag = str(metadata.get("etag") or entity.get("etag") or "")
            try:
                await self.table.update_entity(
                    {
                        "PartitionKey": partition,
                        "RowKey": row_key,
                        "Count": count + 1,
                    },
                    mode=UpdateMode.MERGE,
                    etag=etag,
                    match_condition=MatchConditions.IfNotModified,
                )
                return True
            except ResourceModifiedError:
                continue
        raise RuntimeError("Personal Teams rate counter could not be updated.")

    async def mark_chunk_sent(
        self,
        *,
        turn_id: str,
        chunk_index: int,
        chunk_hash: str,
        teams_activity_id: str,
    ) -> None:
        await self.table.upsert_entity(
            {
                "PartitionKey": f"teams-answer-{sha256(turn_id.encode()).hexdigest()}",
                "RowKey": f"{chunk_index:04d}",
                "ChunkHash": chunk_hash,
                "TeamsActivityId": teams_activity_id,
            },
            mode=UpdateMode.MERGE,
        )

    async def get_sent_chunks(self, turn_id: str) -> dict[int, str]:
        partition = f"teams-answer-{sha256(turn_id.encode()).hexdigest()}"
        entities = self.table.query_entities(
            query_filter=f"PartitionKey eq '{partition}'"
        )
        result: dict[int, str] = {}
        async for entity in entities:
            result[int(entity["RowKey"])] = str(entity.get("ChunkHash", ""))
        return result

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