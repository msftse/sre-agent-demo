import hashlib
import hmac
import json
from dataclasses import dataclass
from typing import Any, Protocol

from azure.core.exceptions import ResourceNotFoundError

from bridge.github_events import (
    ContinuationEvent,
    IgnoredGitHubEvent,
    parse_github_event,
)


class ContinuationState(Protocol):
    async def claim_delivery(self, delivery_id: str) -> bool: ...

    async def get_delivery(self, delivery_id: str) -> dict[str, Any]: ...

    async def mark_delivery(
        self,
        delivery_id: str,
        *,
        teams_sent: bool | None = None,
        sre_sent: bool | None = None,
    ) -> None: ...

    async def save_pull_request(
        self,
        *,
        thread_id: str,
        teams_thread_id: str,
        pr_number: int,
        pr_url: str,
        head_sha: str,
        merge_sha: str = "",
    ) -> None: ...

    async def get_merge_correlation(self, merge_sha: str) -> dict[str, Any]: ...

    async def get_head_correlation(self, head_sha: str) -> dict[str, Any]: ...

    async def claim_alert_monitor(self, merge_sha: str, delivery_id: str) -> bool: ...


class SreContinuation(Protocol):
    async def send_message(self, *, thread_id: str, text: str) -> None: ...


class TeamsContinuation(Protocol):
    async def reply_update(self, thread_id: str, message: str) -> dict[str, str]: ...


class InvalidGitHubSignature(ValueError):
    pass


@dataclass(frozen=True)
class ContinuationResult:
    status: str
    event_key: str = ""
    delivery: dict[str, str | int] | None = None
    start_alert_monitor: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "event_key": self.event_key,
            "delivery": self.delivery,
            "start_alert_monitor": self.start_alert_monitor,
        }


class GitHubContinuationService:
    def __init__(
        self,
        *,
        secret: str,
        expected_repository: str,
        state: ContinuationState,
        sre: SreContinuation,
        teams: TeamsContinuation,
    ) -> None:
        self.secret = secret.encode()
        self.expected_repository = expected_repository
        self.state = state
        self.sre = sre
        self.teams = teams

    async def accept(
        self,
        *,
        body: bytes,
        signature: str,
        delivery_id: str,
        event_type: str,
    ) -> ContinuationResult:
        self._require_signature(body, signature)
        payload = json.loads(body)
        if not isinstance(payload, dict):
            raise IgnoredGitHubEvent("payload")

        correlation = await self._correlation(event_type, payload)
        event = parse_github_event(
            delivery_id=delivery_id,
            event_type=event_type,
            payload=payload,
            expected_repository=self.expected_repository,
            correlation=correlation,
        )
        if event.event_type == "workflow_run" and event.action != "completed":
            return ContinuationResult(status="ignored", event_key=event.event_key)
        if event.event_type == "deployment_status":
            return ContinuationResult(status="ignored", event_key=event.event_key)

        if event.event_type == "pull_request":
            await self.state.save_pull_request(
                thread_id=event.sre_thread_id,
                teams_thread_id=event.teams_thread_id,
                pr_number=event.pr_number,
                pr_url=event.pr_url,
                head_sha=event.head_sha,
                merge_sha=event.merge_sha,
            )
        return ContinuationResult(
            status="accepted",
            event_key=event.event_key,
            delivery=event.to_dict(),
        )

    async def deliver(self, delivery_payload: dict[str, Any]) -> ContinuationResult:
        event = ContinuationEvent.from_dict(delivery_payload)
        start_alert_monitor = False
        if event.event_type == "pull_request":
            await self.state.save_pull_request(
                thread_id=event.sre_thread_id,
                teams_thread_id=event.teams_thread_id,
                pr_number=event.pr_number,
                pr_url=event.pr_url,
                head_sha=event.head_sha,
                merge_sha=event.merge_sha,
            )
        claimed = await self.state.claim_delivery(event.delivery_id)
        delivery = {} if claimed else await self.state.get_delivery(event.delivery_id)
        teams_sent = bool(delivery.get("TeamsSent", False))
        sre_sent = bool(delivery.get("SreSent", False))
        if teams_sent and sre_sent:
            if _starts_alert_monitor(event):
                start_alert_monitor = await self.state.claim_alert_monitor(
                    event.merge_sha,
                    event.delivery_id,
                )
            return ContinuationResult(
                status="duplicate",
                event_key=event.event_key,
                delivery=event.to_dict(),
                start_alert_monitor=start_alert_monitor,
            )

        teams_message, sre_message = _messages(event)
        if not teams_sent:
            if teams_message:
                await self.teams.reply_update(event.teams_thread_id, teams_message)
            await self.state.mark_delivery(event.delivery_id, teams_sent=True)
        if not sre_sent:
            if sre_message:
                await self.sre.send_message(
                    thread_id=event.sre_thread_id,
                    text=sre_message,
                )
            await self.state.mark_delivery(event.delivery_id, sre_sent=True)
        if _starts_alert_monitor(event):
            start_alert_monitor = await self.state.claim_alert_monitor(
                event.merge_sha,
                event.delivery_id,
            )
        return ContinuationResult(
            status="processed",
            event_key=event.event_key,
            delivery=event.to_dict(),
            start_alert_monitor=start_alert_monitor,
        )

    async def process(
        self,
        *,
        body: bytes,
        signature: str,
        delivery_id: str,
        event_type: str,
    ) -> ContinuationResult:
        accepted = await self.accept(
            body=body,
            signature=signature,
            delivery_id=delivery_id,
            event_type=event_type,
        )
        if accepted.delivery is None:
            return accepted
        return await self.deliver(accepted.delivery)

    def _require_signature(self, body: bytes, signature: str) -> None:
        expected = "sha256=" + hmac.new(self.secret, body, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, signature):
            raise InvalidGitHubSignature("signature")

    async def _correlation(
        self,
        event_type: str,
        payload: dict[str, Any],
    ) -> dict[str, Any] | None:
        if event_type == "workflow_run":
            sha = str(payload.get("workflow_run", {}).get("head_sha", ""))
            allow_head_sha = (
                str(payload.get("workflow_run", {}).get("event", ""))
                == "pull_request_target"
            )
        elif event_type == "deployment_status":
            sha = str(payload.get("deployment", {}).get("sha", ""))
            allow_head_sha = True
        else:
            return None
        if not sha:
            return None
        try:
            return await self.state.get_merge_correlation(sha)
        except ResourceNotFoundError:
            if not allow_head_sha:
                return None
        try:
            return await self.state.get_head_correlation(sha)
        except ResourceNotFoundError:
            return None


def _messages(event: ContinuationEvent) -> tuple[str, str]:
    if event.event_type == "pull_request" and event.action in {"opened", "reopened"}:
        milestone = f"Pull request #{event.pr_number} is open: {event.pr_url}"
        boundary = "Awaiting human review; no merge or deployment performed."
    elif event.event_type == "pull_request" and event.conclusion == "merged":
        milestone = (
            f"Pull request #{event.pr_number} was merged by a human at "
            f"{event.merge_sha}."
        )
        boundary = "Awaiting separately approved deployment."
    elif event.event_type == "pull_request":
        milestone = f"Pull request #{event.pr_number} was closed without merge."
        boundary = "Remediation rejected; no deployment will be performed."
    else:
        milestone = f"Delivery workflow {event.action}: {event.conclusion or 'pending'}."
        boundary = f"Release SHA: {event.merge_sha}."

    teams_message = f"{milestone} {boundary}"
    sre_message = (
        "Verified GitHub continuation event. "
        f"{milestone} {boundary} "
        "The Teams timeline already contains this milestone. "
        "Continue the existing investigation without merging, approving, or dispatching a workflow."
    )
    if event.event_type == "workflow_run" and event.conclusion == "success":
        sre_message = ""
    return teams_message, sre_message


def _starts_alert_monitor(event: ContinuationEvent) -> bool:
    return (
        event.event_type == "workflow_run"
        and event.action == "completed"
        and event.conclusion == "success"
    )