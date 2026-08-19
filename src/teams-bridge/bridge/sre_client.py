from dataclasses import dataclass
from typing import Any, Literal
from urllib.parse import urljoin, urlparse

import httpx
from azure.core.credentials_async import AsyncTokenCredential
from azure.identity.aio import DefaultAzureCredential

TurnState = Literal[
    "running",
    "complete",
    "pending_input",
    "approval_required",
    "failed",
    "canceled",
    "unknown",
]


@dataclass(frozen=True)
class SreMessage:
    id: str
    role: str
    text: str
    timestamp: str
    is_complete: bool
    has_approval: bool
    has_user_question: bool


@dataclass(frozen=True)
class SreTurnSnapshot:
    state: TurnState
    raw_state: str
    messages: tuple[SreMessage, ...]

    @property
    def message_ids(self) -> frozenset[str]:
        return frozenset(message.id for message in self.messages if message.id)

    def new_agent_text(self, previous_ids: frozenset[str]) -> tuple[str, ...]:
        return tuple(
            message.text
            for message in self.messages
            if message.id not in previous_ids
            and message.role == "SREAgent"
            and message.is_complete
            and message.text
        )

    def state_after(self, previous_ids: frozenset[str]) -> TurnState:
        messages = [message for message in self.messages if message.id not in previous_ids]
        if any(message.has_approval for message in messages):
            return "approval_required"
        if any(message.has_user_question for message in messages):
            return "pending_input"
        state = _raw_turn_state(self.raw_state)
        if state != "complete":
            return state
        if any(
            message.role == "SREAgent" and message.is_complete and message.text
            for message in messages
        ):
            return "complete"
        return "running"


class SreAgentClient:
    def __init__(
        self,
        endpoint: str,
        credential: AsyncTokenCredential | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.endpoint = endpoint.rstrip("/")
        self.credential = credential or DefaultAzureCredential()
        self.http = http_client or httpx.AsyncClient(timeout=30.0)

    async def _headers(self) -> dict[str, str]:
        token = await self.credential.get_token("https://azuresre.dev/.default")
        return {"Authorization": f"Bearer {token.token}"}

    def _same_origin_url(self, path_or_url: str) -> str:
        url = urljoin(f"{self.endpoint}/", path_or_url)
        expected = urlparse(self.endpoint)
        actual = urlparse(url)
        if (actual.scheme, actual.netloc) != (expected.scheme, expected.netloc):
            raise RuntimeError("SRE pagination changed origin.")
        return url

    async def start_thread(self, *, text: str, user_id: str, display_name: str) -> str:
        response = await self.http.post(
            f"{self.endpoint}/api/v1/threads",
            headers=await self._headers(),
            json={
                "startMessage": {
                    "text": text,
                    "userId": user_id,
                    "displayName": display_name,
                }
            },
        )
        response.raise_for_status()
        payload: dict[str, Any] = response.json()
        thread_id = str(payload.get("id", ""))
        if not thread_id:
            raise RuntimeError("SRE Agent did not return a thread ID.")
        return thread_id

    async def find_thread_by_incident_id(self, incident_id: str) -> str:
        headers = await self._headers()
        url = f"{self.endpoint}/api/v1/threads"
        endpoint_origin = urlparse(self.endpoint)
        seen_urls: set[str] = set()
        threads: list[dict[str, Any]] = []
        while url:
            url_origin = urlparse(url)
            if (url_origin.scheme, url_origin.netloc) != (
                endpoint_origin.scheme,
                endpoint_origin.netloc,
            ):
                raise RuntimeError("SRE thread pagination changed origin.")
            if url in seen_urls or len(seen_urls) >= 100:
                raise RuntimeError("SRE thread pagination did not terminate.")
            seen_urls.add(url)
            response = await self.http.get(url, headers=headers)
            response.raise_for_status()
            payload: Any = response.json()
            if isinstance(payload, list):
                threads.extend(payload)
                break
            threads.extend(payload.get("value", []))
            next_link = str(payload.get("nextLink") or payload.get("@odata.nextLink") or "")
            url = urljoin(f"{self.endpoint}/", next_link) if next_link else ""
        matches = [
            thread
            for thread in threads
            if thread.get("status", {}).get("incidentStatus", {}).get("incidentId")
            == incident_id
        ]
        if len(matches) != 1:
            raise RuntimeError(
                f"Expected one SRE thread for incident {incident_id}, found {len(matches)}."
            )
        thread_id = str(matches[0].get("id", ""))
        if not thread_id:
            raise RuntimeError("Matched SRE Agent thread did not contain an ID.")
        return thread_id

    async def send_message(self, *, thread_id: str, text: str) -> None:
        response = await self.http.post(
            f"{self.endpoint}/api/v1/threads/{thread_id}/messages",
            headers=await self._headers(),
            json={
                "text": text,
                "userId": "github-continuation",
                "displayName": "GitHub Continuation",
            },
        )
        response.raise_for_status()

    async def continue_thread(
        self,
        *,
        thread_id: str,
        text: str,
        user_id: str,
        display_name: str,
    ) -> None:
        response = await self.http.post(
            f"{self.endpoint}/api/v1/threads/{thread_id}/messages",
            headers=await self._headers(),
            json={"text": text, "userId": user_id, "displayName": display_name},
        )
        response.raise_for_status()

    async def get_thread(self, *, thread_id: str) -> dict[str, Any]:
        response = await self.http.get(
            f"{self.endpoint}/api/v1/threads/{thread_id}",
            headers=await self._headers(),
        )
        response.raise_for_status()
        payload: Any = response.json()
        if not isinstance(payload, dict):
            raise RuntimeError("SRE Agent returned an invalid thread payload.")
        return payload

    async def get_thread_messages(self, *, thread_id: str) -> SreTurnSnapshot:
        headers = await self._headers()
        url = f"{self.endpoint}/api/v1/threads/{thread_id}/messages"
        seen_urls: set[str] = set()
        messages: list[SreMessage] = []
        raw_state = ""

        while url:
            url = self._same_origin_url(url)
            if url in seen_urls or len(seen_urls) >= 100:
                raise RuntimeError("SRE message pagination did not terminate.")
            seen_urls.add(url)
            response = await self.http.get(url, headers=headers)
            response.raise_for_status()
            payload: Any = response.json()
            if isinstance(payload, list):
                values = payload
                next_link = ""
            elif isinstance(payload, dict):
                raw_state = str(payload.get("state") or raw_state)
                values = payload.get("value", [])
                next_link = str(
                    payload.get("nextLink") or payload.get("@odata.nextLink") or ""
                )
            else:
                raise RuntimeError("SRE Agent returned an invalid messages payload.")
            if not isinstance(values, list):
                raise RuntimeError("SRE Agent messages value must be a list.")
            messages.extend(_parse_message(value) for value in values)
            url = next_link

        return SreTurnSnapshot(
            state=_normalize_turn_state(raw_state, messages),
            raw_state=raw_state,
            messages=tuple(messages),
        )


def _parse_message(value: Any) -> SreMessage:
    if not isinstance(value, dict):
        raise RuntimeError("SRE Agent returned an invalid message entry.")
    author = value.get("author")
    author = author if isinstance(author, dict) else {}
    message_id = value.get("id")
    role = author.get("role")
    if not isinstance(message_id, str) or not message_id:
        raise RuntimeError("SRE Agent message did not contain a stable ID.")
    if not isinstance(role, str) or not role:
        raise RuntimeError("SRE Agent message did not contain an author role.")
    if not isinstance(value.get("isComplete"), bool):
        raise RuntimeError("SRE Agent message did not contain completion state.")
    return SreMessage(
        id=message_id,
        role=role,
        text=str(value.get("text") or ""),
        timestamp=str(value.get("timeStamp") or ""),
        is_complete=value.get("isComplete") is True,
        has_approval=value.get("approval") is not None,
        has_user_question=value.get("userQuestion") is not None,
    )


def _normalize_turn_state(raw_state: str, messages: list[SreMessage]) -> TurnState:
    if any(message.has_approval for message in messages):
        return "approval_required"
    if any(message.has_user_question for message in messages):
        return "pending_input"
    return _raw_turn_state(raw_state)


def _raw_turn_state(raw_state: str) -> TurnState:
    state = raw_state.casefold()
    if state in {"running", "inprogress", "processing", "active"}:
        return "running"
    if state in {"idle", "complete", "completed"}:
        return "complete"
    if state in {"failed", "error"}:
        return "failed"
    if state in {"canceled", "cancelled"}:
        return "canceled"
    return "unknown"