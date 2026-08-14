from typing import Any
from urllib.parse import urljoin, urlparse

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

    async def find_thread_by_incident_id(self, incident_id: str) -> str:
        token = await self.credential.get_token("https://azuresre.dev/.default")
        headers = {"Authorization": f"Bearer {token.token}"}
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
        token = await self.credential.get_token("https://azuresre.dev/.default")
        response = await self.http.post(
            f"{self.endpoint}/api/v1/threads/{thread_id}/messages",
            headers={"Authorization": f"Bearer {token.token}"},
            json={
                "text": text,
                "userId": "github-continuation",
                "displayName": "GitHub Continuation",
            },
        )
        response.raise_for_status()