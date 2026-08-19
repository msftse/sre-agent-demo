from collections.abc import AsyncIterator
from typing import Any

from azure.core.exceptions import (
    ResourceExistsError,
    ResourceModifiedError,
    ResourceNotFoundError,
)

from bridge.state import BridgeState


class FakeCredential:
    async def get_token(self, *scopes: str, **kwargs: object) -> object:
        del scopes, kwargs
        return object()


class FakeTable:
    def __init__(self) -> None:
        self.entities: dict[tuple[str, str], dict[str, Any]] = {}
        self.modified_failures = 0

    async def upsert_entity(self, entity: dict[str, Any], **_: object) -> None:
        key = (str(entity["PartitionKey"]), str(entity["RowKey"]))
        self.entities[key] = {**self.entities.get(key, {}), **entity}

    async def create_entity(self, entity: dict[str, Any]) -> None:
        key = (str(entity["PartitionKey"]), str(entity["RowKey"]))
        if key in self.entities:
            raise ResourceExistsError("exists")
        self.entities[key] = dict(entity)

    async def get_entity(self, partition_key: str, row_key: str) -> dict[str, Any]:
        try:
            return self.entities[(partition_key, row_key)]
        except KeyError as error:
            raise ResourceNotFoundError("missing") from error

    async def delete_entity(self, partition_key: str, row_key: str) -> None:
        try:
            del self.entities[(partition_key, row_key)]
        except KeyError as error:
            raise ResourceNotFoundError("missing") from error

    async def update_entity(self, entity: dict[str, Any], **_: object) -> None:
        if self.modified_failures:
            self.modified_failures -= 1
            raise ResourceModifiedError("etag changed")
        await self.upsert_entity(entity)

    async def query_entities(
        self,
        query_filter: str,
        **_: object,
    ) -> AsyncIterator[dict[str, Any]]:
        partition = query_filter.split("'", 2)[1]
        for (partition_key, _), entity in self.entities.items():
            if partition_key == partition:
                yield entity


def state() -> BridgeState:
    bridge_state = BridgeState(
        "account", "table", credential=FakeCredential()  # type: ignore[arg-type]
    )
    bridge_state.table = FakeTable()  # type: ignore[assignment]
    return bridge_state


def request(scope: str = "channel", user: str = "user-1") -> dict[str, str]:
    return {
        "scope": scope,
        "tenant_id": "tenant-1",
        "team_id": "team-1" if scope == "channel" else "",
        "channel_id": "channel-1" if scope == "channel" else "",
        "user_object_id": user,
        "conversation_id": "conversation-1",
        "root_activity_id": "root-1" if scope == "channel" else "conversation-1",
        "service_url": "https://smba.trafficmanager.net/teams/",
    }


async def test_channel_and_personal_routes_are_isolated() -> None:
    bridge_state = state()
    channel = request()
    personal = request("personal")

    channel_key = await bridge_state.save_chat_route(
        channel, sre_thread_id="sre-channel", status="idle"
    )
    personal_key = await bridge_state.save_chat_route(
        personal, sre_thread_id="sre-personal", status="idle"
    )

    assert channel_key != personal_key
    assert (await bridge_state.get_chat_route(channel_key))["SreThreadId"] == "sre-channel"  # type: ignore[index]
    assert (await bridge_state.get_chat_route(personal_key))["SreThreadId"] == "sre-personal"  # type: ignore[index]
    assert BridgeState.chat_route_key(request("personal", "user-2")) != personal_key


def test_channel_route_follows_teams_conversation_id() -> None:
    root = request()
    reply = {**root, "root_activity_id": "different-message-id"}
    other_thread = {**root, "conversation_id": "conversation-2"}

    assert BridgeState.chat_route_key(root) == BridgeState.chat_route_key(reply)
    assert BridgeState.chat_route_key(root) != BridgeState.chat_route_key(other_thread)


async def test_deduplicates_inbound_turns_and_serializes_route() -> None:
    bridge_state = state()

    assert await bridge_state.claim_inbound_turn("activity-1") is True
    assert await bridge_state.claim_inbound_turn("activity-1") is False
    assert await bridge_state.claim_chat_turn("route-1", "turn-1") is True
    assert await bridge_state.claim_chat_turn("route-1", "turn-2") is False
    await bridge_state.release_chat_turn("route-1", "wrong-turn")
    assert await bridge_state.claim_chat_turn("route-1", "turn-2") is False
    await bridge_state.release_chat_turn("route-1", "turn-1")
    assert await bridge_state.claim_chat_turn("route-1", "turn-2") is True


async def test_clears_only_selected_route() -> None:
    bridge_state = state()
    first = await bridge_state.save_chat_route(
        request("personal", "user-1"), sre_thread_id="sre-1", status="idle"
    )
    second = await bridge_state.save_chat_route(
        request("personal", "user-2"), sre_thread_id="sre-2", status="idle"
    )

    assert await bridge_state.clear_chat_route(first) is True
    assert await bridge_state.clear_chat_route(first) is False
    assert await bridge_state.get_chat_route(second) is not None


async def test_enforces_personal_rate_window() -> None:
    bridge_state = state()

    assert await bridge_state.claim_personal_rate(
        user_object_id="user-1", activity_id="activity-1", window="2026081907", limit=2
    )
    assert await bridge_state.claim_personal_rate(
        user_object_id="user-1", activity_id="activity-2", window="2026081907", limit=2
    )
    assert not await bridge_state.claim_personal_rate(
        user_object_id="user-1", activity_id="activity-3", window="2026081907", limit=2
    )
    assert await bridge_state.claim_personal_rate(
        user_object_id="user-2", activity_id="activity-3", window="2026081907", limit=2
    )


async def test_retries_personal_rate_counter_after_etag_conflict() -> None:
    bridge_state = state()
    table = bridge_state.table
    assert isinstance(table, FakeTable)

    assert await bridge_state.claim_personal_rate(
        user_object_id="user-1", activity_id="activity-1", window="2026081907", limit=2
    )
    table.modified_failures = 1
    assert await bridge_state.claim_personal_rate(
        user_object_id="user-1", activity_id="activity-2", window="2026081907", limit=2
    )
    assert not await bridge_state.claim_personal_rate(
        user_object_id="user-1", activity_id="activity-3", window="2026081907", limit=2
    )


async def test_tracks_delivery_chunks_without_answer_text() -> None:
    bridge_state = state()

    await bridge_state.mark_chunk_sent(
        turn_id="turn-1",
        chunk_index=0,
        chunk_hash="hash-1",
        teams_activity_id="activity-1",
    )

    assert await bridge_state.get_sent_chunks("turn-1") == {0: "hash-1"}