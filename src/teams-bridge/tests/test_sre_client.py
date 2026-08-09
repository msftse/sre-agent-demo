from dataclasses import dataclass

import httpx

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