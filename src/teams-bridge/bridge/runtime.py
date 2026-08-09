import hmac
import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any

import azure.functions as func
from fastapi import FastAPI
from mcp.server import MCPServer
from mcp.server.transport_security import TransportSecuritySettings
from microsoft_teams.apps import App as TeamsApp
from microsoft_teams.apps.http.fastapi_adapter import FastAPIAdapter

from bridge.boundary import TeamsBoundary
from bridge.config import Settings
from bridge.notifications import NotificationService
from bridge.sre_client import SreAgentClient
from bridge.state import BridgeState


class SharedKeyMiddleware:
    def __init__(self, app: Any, shared_key: str) -> None:
        self.app = app
        self.shared_key = shared_key.encode()

    async def __call__(self, scope: Any, receive: Any, send: Any) -> None:
        if scope["type"] == "http":
            headers = {key.lower(): value for key, value in scope.get("headers", [])}
            supplied = headers.get(b"x-mcp-key", b"")
            if not hmac.compare_digest(supplied, self.shared_key):
                await send(
                    {
                        "type": "http.response.start",
                        "status": 401,
                        "headers": [(b"content-type", b"application/json")],
                    }
                )
                await send(
                    {
                        "type": "http.response.body",
                        "body": b'{"error":"unauthorized"}',
                    }
                )
                return
        await self.app(scope, receive, send)


class BridgeRuntime:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.boundary = TeamsBoundary(
            tenant_id=settings.teams_tenant_id,
            team_id=settings.teams_team_id,
            channel_id=settings.teams_channel_id,
            allowed_user_object_id=settings.allowed_user_object_id,
        )
        self.state = BridgeState(
            settings.storage_account_name,
            settings.storage_table_name,
        )
        self.sre = SreAgentClient(settings.sre_agent_endpoint)
        self.web = FastAPI(
            title="Azure SRE Agent Teams bridge",
            lifespan=self._lifespan,
        )
        self.teams_adapter = FastAPIAdapter(self.web)
        self.teams = TeamsApp(
            client_id=settings.bot_client_id,
            client_secret=settings.bot_client_secret,
            tenant_id=settings.bot_tenant_id,
            http_server_adapter=self.teams_adapter,
        )
        self.notifications = NotificationService(self.teams, self.state)
        self.mcp = self._create_mcp_server()
        hostname = os.getenv("WEBSITE_HOSTNAME", "localhost")
        self.mcp_app = self.mcp.streamable_http_app(
            streamable_http_path="/",
            json_response=True,
            stateless_http=True,
            transport_security=TransportSecuritySettings(
                allowed_hosts=[hostname],
                allowed_origins=[f"https://{hostname}"],
            ),
        )
        self.web.mount(
            "/api/mcp",
            SharedKeyMiddleware(self.mcp_app, settings.mcp_shared_key),
        )
        self.web.add_api_route("/api/health", self.health, methods=["GET"])
        self.web.add_api_route("/privacy", self.privacy, methods=["GET"])
        self.web.add_api_route("/terms", self.terms, methods=["GET"])
        self.asgi = func.AsgiMiddleware(self.web)  # type: ignore[no-untyped-call]
        self._initialized = False

    def _create_mcp_server(self) -> MCPServer:
        server = MCPServer(
            "northstar-teams",
            instructions=(
                "Post Northstar incident milestones only. The destination is fixed "
                "server-side; never include secrets or customer payloads."
            ),
        )

        @server.tool()
        async def post_incident_update(thread_id: str, message: str) -> dict[str, str]:
            """Start a Teams incident thread in the fixed Northstar channel."""
            return await self.notifications.post_update(thread_id, message)

        @server.tool()
        async def reply_incident_thread(thread_id: str, message: str) -> dict[str, str]:
            """Reply to an existing Teams incident thread in the fixed channel."""
            return await self.notifications.reply_update(thread_id, message)

        @server.tool()
        async def get_incident_thread(thread_id: str) -> dict[str, str]:
            """Return stored routing metadata for a Teams incident thread."""
            return await self.notifications.get_thread(thread_id)

        return server

    async def initialize(self) -> None:
        if self._initialized:
            return
        await self.teams.initialize()
        await self.asgi.notify_startup()  # type: ignore[no-untyped-call]
        self._initialized = True

    async def health(self) -> dict[str, str]:
        return {"status": "ok"}

    async def privacy(self) -> dict[str, str]:
        return {"privacy": "No message bodies are retained in routine application logs."}

    async def terms(self) -> dict[str, str]:
        return {"terms": "For use only in the Northstar Azure SRE Agent demo."}

    @asynccontextmanager
    async def _lifespan(self, _: FastAPI) -> AsyncIterator[None]:
        async with self.mcp_app.router.lifespan_context(self.mcp_app):
            yield