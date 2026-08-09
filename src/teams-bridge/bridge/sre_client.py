from typing import Any

import httpx
from azure.core.credentials_async import AsyncTokenCredential
from azure.identity.aio import DefaultAzureCredential


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

    async def start_thread(self, *, text: str, user_id: str, display_name: str) -> str:
        token = await self.credential.get_token("https://azuresre.dev/.default")
        response = await self.http.post(
            f"{self.endpoint}/api/v1/threads",
            headers={"Authorization": f"Bearer {token.token}"},
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