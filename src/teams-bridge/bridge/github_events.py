import re
from dataclasses import dataclass
from typing import Any

EXPECTED_REPOSITORY = "msftse/sre-agent-demo"
EXPECTED_WORKFLOW = "Deliver demo to AKS"
THREAD_MARKER = re.compile(r"<!--\s*sre-thread-id:\s*([A-Za-z0-9._:-]+)\s*-->")


class IgnoredGitHubEvent(ValueError):
    pass


@dataclass(frozen=True)
class ContinuationEvent:
    delivery_id: str
    event_type: str
    action: str
    repository: str
    sre_thread_id: str
    pr_number: int
    pr_url: str
    head_sha: str
    merge_sha: str
    conclusion: str

    @property
    def event_key(self) -> str:
        return f"{self.event_type}:{self.action}:{self.delivery_id}"


def parse_github_event(
    *,
    delivery_id: str,
    event_type: str,
    payload: dict[str, Any],
    correlation: dict[str, Any] | None = None,
) -> ContinuationEvent:
    repository = str(payload.get("repository", {}).get("full_name", ""))
    if repository != EXPECTED_REPOSITORY:
        raise IgnoredGitHubEvent("repository")
    if not delivery_id:
        raise IgnoredGitHubEvent("delivery")

    action = str(payload.get("action", ""))
    if event_type == "pull_request":
        return _parse_pull_request(delivery_id, action, repository, payload)
    if event_type == "workflow_run":
        return _parse_workflow_run(
            delivery_id,
            action,
            repository,
            payload,
            correlation,
        )
    if event_type == "deployment_status":
        return _parse_deployment_status(
            delivery_id,
            action,
            repository,
            payload,
            correlation,
        )
    raise IgnoredGitHubEvent("event")


def _parse_pull_request(
    delivery_id: str,
    action: str,
    repository: str,
    payload: dict[str, Any],
) -> ContinuationEvent:
    if action not in {"opened", "reopened", "closed"}:
        raise IgnoredGitHubEvent("pull_request_action")
    pull_request = payload.get("pull_request", {})
    body = str(pull_request.get("body") or "")
    markers = THREAD_MARKER.findall(body)
    if len(markers) != 1:
        raise IgnoredGitHubEvent("thread_marker")
    head = pull_request.get("head", {})
    base = pull_request.get("base", {})
    if str(head.get("repo", {}).get("full_name", "")) != EXPECTED_REPOSITORY:
        raise IgnoredGitHubEvent("head_repository")
    if not str(head.get("ref", "")).startswith("sre/field20-checkout-"):
        raise IgnoredGitHubEvent("head_branch")
    if str(base.get("repo", {}).get("full_name", "")) != EXPECTED_REPOSITORY:
        raise IgnoredGitHubEvent("base_repository")
    if str(base.get("ref", "")) != "main":
        raise IgnoredGitHubEvent("base_branch")

    merged = bool(pull_request.get("merged", False))
    conclusion = ""
    if action == "closed":
        conclusion = "merged" if merged else "rejected"

    return ContinuationEvent(
        delivery_id=delivery_id,
        event_type="pull_request",
        action=action,
        repository=repository,
        sre_thread_id=markers[0],
        pr_number=int(payload.get("number", 0)),
        pr_url=str(pull_request.get("html_url", "")),
        head_sha=str(pull_request.get("head", {}).get("sha", "")),
        merge_sha=str(pull_request.get("merge_commit_sha") or "") if merged else "",
        conclusion=conclusion,
    )


def _parse_workflow_run(
    delivery_id: str,
    action: str,
    repository: str,
    payload: dict[str, Any],
    correlation: dict[str, Any] | None,
) -> ContinuationEvent:
    workflow_run = payload.get("workflow_run", {})
    if str(workflow_run.get("name", "")) != EXPECTED_WORKFLOW:
        raise IgnoredGitHubEvent("workflow")
    if str(workflow_run.get("event", "")) not in {
        "pull_request_target",
        "workflow_dispatch",
    }:
        raise IgnoredGitHubEvent("workflow_event")
    if str(workflow_run.get("head_branch", "")) != "main":
        raise IgnoredGitHubEvent("workflow_branch")
    if action not in {"requested", "in_progress", "completed"}:
        raise IgnoredGitHubEvent("workflow_action")
    if correlation is None:
        raise IgnoredGitHubEvent("correlation")

    return ContinuationEvent(
        delivery_id=delivery_id,
        event_type="workflow_run",
        action=action,
        repository=repository,
        sre_thread_id=str(correlation["SreThreadId"]),
        pr_number=int(correlation["PrNumber"]),
        pr_url=str(correlation["PrUrl"]),
        head_sha=str(workflow_run.get("head_sha", "")),
        merge_sha=str(correlation["MergeSha"]),
        conclusion=str(workflow_run.get("conclusion") or ""),
    )


def _parse_deployment_status(
    delivery_id: str,
    action: str,
    repository: str,
    payload: dict[str, Any],
    correlation: dict[str, Any] | None,
) -> ContinuationEvent:
    if action != "created":
        raise IgnoredGitHubEvent("deployment_status_action")
    if correlation is None:
        raise IgnoredGitHubEvent("correlation")
    deployment = payload.get("deployment", {})
    deployment_status = payload.get("deployment_status", {})
    if str(deployment.get("environment", "")) != "demo":
        raise IgnoredGitHubEvent("environment")

    return ContinuationEvent(
        delivery_id=delivery_id,
        event_type="deployment_status",
        action=action,
        repository=repository,
        sre_thread_id=str(correlation["SreThreadId"]),
        pr_number=int(correlation["PrNumber"]),
        pr_url=str(correlation["PrUrl"]),
        head_sha=str(deployment.get("sha", "")),
        merge_sha=str(correlation["MergeSha"]),
        conclusion=str(deployment_status.get("state") or ""),
    )