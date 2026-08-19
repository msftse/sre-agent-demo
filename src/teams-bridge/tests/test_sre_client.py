from dataclasses import dataclass

import httpx
import pytest

from bridge.sre_client import SreAgentClient


@dataclass
class Token:
    token: str


class Credential:
    def __init__(self) -> None:
        self.scope = ""

    async def get_token(self, *scopes: str, **kwargs: object) -> Token:
        del kwargs
        self.scope = scopes[0]
        return Token("token")


async def test_creates_sre_thread_with_verified_payload() -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer token"
        assert request.url.path == "/api/v1/threads"
        assert request.content == (
            b'{"startMessage":{"text":"investigate","userId":"user-1",'
            b'"displayName":"Operator"}}'
        )
        return httpx.Response(200, json={"id": "thread-1"})

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=http,
    )

    thread_id = await client.start_thread(
        text="investigate",
        user_id="user-1",
        display_name="Operator",
    )

    assert thread_id == "thread-1"
    assert credential.scope == "https://azuresre.dev/.default"


async def test_sends_continuation_message_to_existing_thread() -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer token"
        assert request.url.path == "/api/v1/threads/thread-1/messages"
        assert request.content == (
            b'{"text":"Pull request merged at abc123.",'
            b'"userId":"github-continuation",'
            b'"displayName":"GitHub Continuation"}'
        )
        return httpx.Response(202)

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=http,
    )

    await client.send_message(
        thread_id="thread-1",
        text="Pull request merged at abc123.",
    )

    assert credential.scope == "https://azuresre.dev/.default"


async def test_continues_thread_as_teams_user() -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v1/threads/thread-1/messages"
        assert request.content == (
            b'{"text":"show node health","userId":"user-1","displayName":"Operator"}'
        )
        return httpx.Response(202)

    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    await client.continue_thread(
        thread_id="thread-1",
        text="show node health",
        user_id="user-1",
        display_name="Operator",
    )


async def test_reads_completed_turn_and_selects_new_agent_text() -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v1/threads/thread-1/messages"
        return httpx.Response(
            200,
            json={
                "state": "Idle",
                "value": [
                    {
                        "id": "user-message",
                        "author": {"role": "User"},
                        "text": "question",
                        "timeStamp": "2026-08-19T01:00:00Z",
                        "isComplete": True,
                    },
                    {
                        "id": "old-agent-message",
                        "author": {"role": "SREAgent"},
                        "text": "old answer",
                        "timeStamp": "2026-08-19T01:00:01Z",
                        "isComplete": True,
                    },
                    {
                        "id": "new-agent-message",
                        "author": {"role": "SREAgent"},
                        "text": "new answer",
                        "timeStamp": "2026-08-19T01:00:02Z",
                        "isComplete": True,
                    },
                ],
            },
        )

    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    snapshot = await client.get_thread_messages(thread_id="thread-1")

    assert snapshot.state == "complete"
    assert snapshot.new_agent_text(frozenset({"old-agent-message"})) == ("new answer",)
    assert snapshot.state_after(frozenset({"user-message", "old-agent-message"})) == (
        "complete"
    )


async def test_idle_snapshot_waits_when_no_new_agent_answer_exists() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "state": "Idle",
                "value": [
                    {
                        "id": "existing",
                        "author": {"role": "SREAgent"},
                        "text": "old answer",
                        "isComplete": True,
                    }
                ],
            },
        )

    client = SreAgentClient(
        "https://agent.example",
        credential=Credential(),  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    snapshot = await client.get_thread_messages(thread_id="thread-1")

    assert snapshot.state_after(frozenset({"existing"})) == "running"


async def test_reads_paginated_messages_and_rejects_cross_origin() -> None:
    credential = Credential()

    def paged_handler(request: httpx.Request) -> httpx.Response:
        if "page" not in request.url.params:
            return httpx.Response(
                200,
                json={
                    "state": "Running",
                    "value": [],
                    "nextLink": "https://agent.example/api/v1/threads/thread-1/messages?page=2",
                },
            )
        return httpx.Response(200, json={"state": "Idle", "value": []})

    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(paged_handler)),
    )
    assert (await client.get_thread_messages(thread_id="thread-1")).state == "complete"

    def hostile_handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"value": [], "nextLink": "https://untrusted.example/messages?page=2"},
        )

    hostile_client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(hostile_handler)),
    )
    with pytest.raises(RuntimeError, match="pagination changed origin"):
        await hostile_client.get_thread_messages(thread_id="thread-1")


@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        ({"state": "Running", "value": []}, "running"),
        (
            {
                "state": "Idle",
                "value": [
                    {
                        "id": "1",
                        "author": {"role": "SREAgent"},
                        "isComplete": True,
                        "approval": {"id": "approval"},
                    }
                ],
            },
            "approval_required",
        ),
        (
            {
                "state": "Idle",
                "value": [
                    {
                        "id": "1",
                        "author": {"role": "SREAgent"},
                        "isComplete": True,
                        "userQuestion": {"text": "more"},
                    }
                ],
            },
            "pending_input",
        ),
        ({"state": "SomethingNew", "value": []}, "unknown"),
    ],
)
async def test_normalizes_turn_states(payload: dict[str, object], expected: str) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=payload)

    client = SreAgentClient(
        "https://agent.example",
        credential=Credential(),  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    assert (await client.get_thread_messages(thread_id="thread-1")).state == expected


async def test_finds_thread_by_incident_id() -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer token"
        assert request.url.path == "/api/v1/threads"
        return httpx.Response(
            200,
            json=[
                {
                    "id": "sre-1",
                    "status": {
                        "incidentStatus": {
                            "incidentId": "incident-1",
                            "status": "acknowledged",
                        }
                    },
                },
                {
                    "id": "sre-2",
                    "status": {
                        "incidentStatus": {
                            "incidentId": "incident-2",
                            "status": "resolved",
                        }
                    },
                },
            ],
        )

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=http,
    )

    thread_id = await client.find_thread_by_incident_id("incident-1")

    assert thread_id == "sre-1"
    assert credential.scope == "https://azuresre.dev/.default"


async def test_finds_thread_by_incident_id_across_pages() -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        if "page" not in request.url.params:
            return httpx.Response(
                200,
                json={
                    "value": [],
                    "nextLink": "https://agent.example/api/v1/threads?page=2",
                },
            )
        assert request.url.params["page"] == "2"
        return httpx.Response(
            200,
            json={
                "value": [
                    {
                        "id": "sre-1",
                        "status": {"incidentStatus": {"incidentId": "incident-1"}},
                    }
                ]
            },
        )

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=http,
    )

    assert await client.find_thread_by_incident_id("incident-1") == "sre-1"


async def test_rejects_cross_origin_thread_pagination() -> None:
    credential = Credential()
    requested_hosts: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requested_hosts.append(request.url.host)
        return httpx.Response(
            200,
            json={
                "value": [],
                "nextLink": "https://untrusted.example/api/v1/threads?page=2",
            },
        )

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=http,
    )

    with pytest.raises(RuntimeError, match="pagination changed origin"):
        await client.find_thread_by_incident_id("incident-1")

    assert requested_hosts == ["agent.example"]


@pytest.mark.parametrize("matching_threads", [0, 2])
async def test_rejects_missing_or_ambiguous_incident_threads(
    matching_threads: int,
) -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v1/threads"
        return httpx.Response(
            200,
            json=[
                {
                    "id": f"sre-{index}",
                    "status": {"incidentStatus": {"incidentId": "incident-1"}},
                }
                for index in range(matching_threads)
            ],
        )

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client = SreAgentClient(
        "https://agent.example",
        credential=credential,  # type: ignore[arg-type]
        http_client=http,
    )

    with pytest.raises(
        RuntimeError,
        match=f"Expected one SRE thread for incident incident-1, found {matching_threads}",
    ):
        await client.find_thread_by_incident_id("incident-1")