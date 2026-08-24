from dataclasses import dataclass

import httpx
import pytest

from bridge.alert_management import (
    AlertManagementClient,
    AlertManagementTemporaryError,
    AlertManagementTerminalError,
)


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


@pytest.mark.parametrize("condition", ["Fired", "Resolved"])
async def test_reads_alert_monitor_condition(condition: str) -> None:
    credential = Credential()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer token"
        assert request.url.path == (
            "/subscriptions/subscription-1/providers/"
            "Microsoft.AlertsManagement/alerts/alert-1"
        )
        assert request.url.params["api-version"] == "2019-03-01"
        return httpx.Response(
            200,
            json={
                "properties": {
                    "essentials": {
                        "monitorCondition": condition,
                        "alertState": "Acknowledged",
                    }
                }
            },
        )

    client = AlertManagementClient(
        "subscription-1",
        credential=credential,  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    snapshot = await client.get_alert("alert-1")

    assert snapshot.condition == condition
    assert snapshot.alert_state == "Acknowledged"
    assert credential.scope == "https://management.azure.com/.default"


@pytest.mark.parametrize("status_code", [408, 429, 500, 503])
async def test_classifies_temporary_http_failures(status_code: int) -> None:
    client = AlertManagementClient(
        "subscription-1",
        credential=Credential(),  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda request: httpx.Response(status_code, request=request)
            )
        ),
    )

    with pytest.raises(AlertManagementTemporaryError, match=f"HTTP {status_code}"):
        await client.get_alert("alert-1")


@pytest.mark.parametrize("status_code", [400, 401, 403, 404])
async def test_classifies_terminal_http_failures(status_code: int) -> None:
    client = AlertManagementClient(
        "subscription-1",
        credential=Credential(),  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda request: httpx.Response(status_code, request=request)
            )
        ),
    )

    with pytest.raises(AlertManagementTerminalError, match=f"HTTP {status_code}"):
        await client.get_alert("alert-1")


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"properties": {}},
        {"properties": {"essentials": {}}},
        {"properties": {"essentials": {"monitorCondition": "Unknown"}}},
    ],
)
async def test_rejects_unknown_or_missing_monitor_condition(
    payload: dict[str, object],
) -> None:
    client = AlertManagementClient(
        "subscription-1",
        credential=Credential(),  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda request: httpx.Response(200, json=payload, request=request)
            )
        ),
    )

    with pytest.raises(AlertManagementTerminalError, match="monitor condition"):
        await client.get_alert("alert-1")


async def test_classifies_transport_failure_as_temporary() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out", request=request)

    client = AlertManagementClient(
        "subscription-1",
        credential=Credential(),  # type: ignore[arg-type]
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    with pytest.raises(AlertManagementTemporaryError, match="temporarily"):
        await client.get_alert("alert-1")