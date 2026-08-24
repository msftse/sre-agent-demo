from dataclasses import dataclass
from typing import Any, Literal
from urllib.parse import quote

import httpx
from azure.core.credentials_async import AsyncTokenCredential
from azure.identity.aio import DefaultAzureCredential

AlertCondition = Literal["Fired", "Resolved"]


class AlertManagementError(RuntimeError):
    pass


class AlertManagementTemporaryError(AlertManagementError):
    pass


class AlertManagementTerminalError(AlertManagementError):
    pass


@dataclass(frozen=True)
class AlertSnapshot:
    condition: AlertCondition
    alert_state: str


class AlertManagementClient:
    def __init__(
        self,
        subscription_id: str,
        credential: AsyncTokenCredential | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.subscription_id = subscription_id
        self.credential = credential or DefaultAzureCredential()
        self.http = http_client or httpx.AsyncClient(timeout=30.0)

    async def get_alert(self, alert_id: str) -> AlertSnapshot:
        token = await self.credential.get_token("https://management.azure.com/.default")
        subscription_id = quote(self.subscription_id, safe="")
        encoded_alert_id = quote(alert_id, safe="")
        url = (
            "https://management.azure.com/subscriptions/"
            f"{subscription_id}/providers/Microsoft.AlertsManagement/alerts/"
            f"{encoded_alert_id}?api-version=2019-03-01"
        )
        try:
            response = await self.http.get(
                url,
                headers={"Authorization": f"Bearer {token.token}"},
            )
        except (httpx.TimeoutException, httpx.TransportError) as error:
            raise AlertManagementTemporaryError(
                "Azure AlertsManagement request failed temporarily."
            ) from error

        if response.status_code in {408, 429} or response.status_code >= 500:
            raise AlertManagementTemporaryError(
                f"Azure AlertsManagement returned HTTP {response.status_code}."
            )
        if response.status_code >= 400:
            raise AlertManagementTerminalError(
                f"Azure AlertsManagement returned HTTP {response.status_code}."
            )

        try:
            payload: Any = response.json()
        except ValueError as error:
            raise AlertManagementTerminalError(
                "Azure AlertsManagement returned invalid JSON."
            ) from error
        if not isinstance(payload, dict):
            raise AlertManagementTerminalError(
                "Azure AlertsManagement returned an invalid alert payload."
            )
        properties = payload.get("properties")
        properties = properties if isinstance(properties, dict) else {}
        essentials = properties.get("essentials")
        essentials = essentials if isinstance(essentials, dict) else {}
        condition = essentials.get("monitorCondition")
        if condition not in {"Fired", "Resolved"}:
            raise AlertManagementTerminalError(
                "Azure AlertsManagement returned an unknown monitor condition."
            )
        alert_state = essentials.get("alertState")
        return AlertSnapshot(
            condition=condition,
            alert_state=alert_state if isinstance(alert_state, str) else "",
        )