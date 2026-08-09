import hashlib
import hmac
import json
from typing import Any

import pytest

from bridge.github_continuation import (
    GitHubContinuationService,
    InvalidGitHubSignature,
)


class FakeState:
    def __init__(self) -> None:
        self.claimed: set[str] = set()
        self.saved: list[dict[str, Any]] = []
        self.deliveries: dict[str, dict[str, bool]] = {}

    async def claim_delivery(self, delivery_id: str) -> bool:
        if delivery_id in self.claimed:
            return False
        self.claimed.add(delivery_id)
        self.deliveries[delivery_id] = {}
        return True

    async def get_delivery(self, delivery_id: str) -> dict[str, Any]:
        return dict(self.deliveries[delivery_id])

    async def mark_delivery(
        self,
        delivery_id: str,
        *,
        teams_sent: bool | None = None,
        sre_sent: bool | None = None,
    ) -> None:
        if teams_sent is not None:
            self.deliveries[delivery_id]["TeamsSent"] = teams_sent
        if sre_sent is not None:
            self.deliveries[delivery_id]["SreSent"] = sre_sent

    async def save_pull_request(self, **values: Any) -> None:
        self.saved.append(values)

    async def get_merge_correlation(self, merge_sha: str) -> dict[str, Any]:
        assert merge_sha == "merge-123"
        return {
            "SreThreadId": "thread-1",
            "PrNumber": 42,
            "PrUrl": "https://github.com/msftse/sre-agent-demo/pull/42",
            "MergeSha": "merge-123",
        }


class FakeSre:
    def __init__(self, *, fail: bool = False) -> None:
        self.fail = fail
        self.messages: list[tuple[str, str]] = []

    async def send_message(self, *, thread_id: str, text: str) -> None:
        if self.fail:
            raise RuntimeError("SRE unavailable")
        self.messages.append((thread_id, text))


class FakeTeams:
    def __init__(self, *, fail: bool = False) -> None:
        self.fail = fail
        self.messages: list[tuple[str, str]] = []

    async def reply_update(self, thread_id: str, message: str) -> dict[str, str]:
        if self.fail:
            raise RuntimeError("Teams unavailable")
        self.messages.append((thread_id, message))
        return {"thread_id": thread_id, "teams_activity_id": "reply-1"}


def signed(body: bytes) -> str:
    return "sha256=" + hmac.new(b"secret", body, hashlib.sha256).hexdigest()


def pull_request_body() -> bytes:
    return json.dumps(
        {
            "action": "opened",
            "number": 42,
            "repository": {"full_name": "msftse/sre-agent-demo"},
            "pull_request": {
                "body": "<!-- sre-thread-id: thread-1 -->",
                "html_url": "https://github.com/msftse/sre-agent-demo/pull/42",
                "merged": False,
                "head": {
                    "sha": "head-123",
                    "ref": "sre/field20-checkout-thread-1",
                    "repo": {"full_name": "msftse/sre-agent-demo"},
                },
                "base": {
                    "ref": "main",
                    "repo": {"full_name": "msftse/sre-agent-demo"},
                },
            },
        },
        separators=(",", ":"),
    ).encode()


async def test_processes_and_deduplicates_pull_request() -> None:
    state = FakeState()
    sre = FakeSre()
    teams = FakeTeams()
    service = GitHubContinuationService(
        secret="secret",
        state=state,
        sre=sre,
        teams=teams,
    )
    body = pull_request_body()

    processed = await service.process(
        body=body,
        signature=signed(body),
        delivery_id="delivery-1",
        event_type="pull_request",
    )
    duplicate = await service.process(
        body=body,
        signature=signed(body),
        delivery_id="delivery-1",
        event_type="pull_request",
    )

    assert processed.status == "processed"
    assert duplicate.status == "duplicate"
    assert state.saved[0]["pr_number"] == 42
    assert teams.messages[0][0] == "thread-1"
    assert "Awaiting human review" in teams.messages[0][1]
    assert "without merging, approving, or dispatching" in sre.messages[0][1]


async def test_rejects_invalid_signature_before_state_changes() -> None:
    state = FakeState()
    service = GitHubContinuationService(
        secret="secret",
        state=state,
        sre=FakeSre(),
        teams=FakeTeams(),
    )

    with pytest.raises(InvalidGitHubSignature):
        await service.process(
            body=pull_request_body(),
            signature="sha256=invalid",
            delivery_id="delivery-2",
            event_type="pull_request",
        )

    assert state.claimed == set()


async def test_retries_only_missing_downstream_notification() -> None:
    state = FakeState()
    sre = FakeSre()
    service = GitHubContinuationService(
        secret="secret",
        state=state,
        sre=sre,
        teams=FakeTeams(fail=True),
    )
    body = pull_request_body()

    with pytest.raises(RuntimeError, match="Teams unavailable"):
        await service.process(
            body=body,
            signature=signed(body),
            delivery_id="delivery-3",
            event_type="pull_request",
        )

    assert state.deliveries["delivery-3"] == {}
    assert sre.messages == []

    service.teams = FakeTeams()
    result = await service.process(
        body=body,
        signature=signed(body),
        delivery_id="delivery-3",
        event_type="pull_request",
    )

    assert result.status == "processed"
    assert state.deliveries["delivery-3"] == {"TeamsSent": True, "SreSent": True}


async def test_continues_successful_workflow_for_correlated_merge() -> None:
    state = FakeState()
    sre = FakeSre()
    service = GitHubContinuationService(
        secret="secret",
        state=state,
        sre=sre,
        teams=FakeTeams(),
    )
    body = json.dumps(
        {
            "action": "completed",
            "repository": {"full_name": "msftse/sre-agent-demo"},
            "workflow_run": {
                "name": "Deliver demo to AKS",
                "event": "workflow_dispatch",
                "head_branch": "main",
                "head_sha": "merge-123",
                "conclusion": "success",
            },
        },
        separators=(",", ":"),
    ).encode()

    result = await service.process(
        body=body,
        signature=signed(body),
        delivery_id="delivery-4",
        event_type="workflow_run",
    )

    assert result.status == "processed"
    assert "verify the deployed SHA" in sre.messages[0][1]


async def test_redelivery_skips_teams_after_sre_failure() -> None:
    state = FakeState()
    teams = FakeTeams()
    sre = FakeSre(fail=True)
    service = GitHubContinuationService(
        secret="secret",
        state=state,
        sre=sre,
        teams=teams,
    )
    body = pull_request_body()

    with pytest.raises(RuntimeError, match="SRE unavailable"):
        await service.process(
            body=body,
            signature=signed(body),
            delivery_id="delivery-5",
            event_type="pull_request",
        )

    assert len(teams.messages) == 1
    assert state.deliveries["delivery-5"] == {"TeamsSent": True}

    service.sre = FakeSre()
    result = await service.process(
        body=body,
        signature=signed(body),
        delivery_id="delivery-5",
        event_type="pull_request",
    )

    assert result.status == "processed"
    assert len(teams.messages) == 1
    assert state.deliveries["delivery-5"] == {"TeamsSent": True, "SreSent": True}