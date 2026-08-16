import pytest

from bridge.github_events import IgnoredGitHubEvent, parse_github_event

EXPECTED_REPOSITORY = "msftse/sre-agent-demo"


def repository(full_name: str = EXPECTED_REPOSITORY) -> dict[str, str]:
    return {"full_name": full_name}


def pull_request_payload(*, action: str, merged: bool = False) -> dict[str, object]:
    return {
        "action": action,
        "number": 42,
        "repository": repository(),
        "pull_request": {
            "body": (
                "Fix checkout\n\n"
                "<!-- sre-thread-id: sre-thread-1 -->\n"
                "<!-- teams-thread-id: incident-1 -->"
            ),
            "html_url": "https://github.com/msftse/sre-agent-demo/pull/42",
            "merged": merged,
            "merge_commit_sha": "merge-123" if merged else None,
            "head": {
                "sha": "head-123",
                "ref": "sre/field20-checkout-incident-1",
                "repo": repository(),
            },
            "base": {"ref": "main", "repo": repository()},
        },
    }


def test_parses_opened_pull_request_marker() -> None:
    event = parse_github_event(
        delivery_id="delivery-1",
        event_type="pull_request",
        payload=pull_request_payload(action="opened"),
        expected_repository=EXPECTED_REPOSITORY,
    )

    assert event.sre_thread_id == "sre-thread-1"
    assert event.teams_thread_id == "incident-1"
    assert event.pr_number == 42
    assert event.conclusion == ""


def test_rejects_empty_expected_repository() -> None:
    with pytest.raises(IgnoredGitHubEvent, match="expected_repository"):
        parse_github_event(
            delivery_id="delivery-empty-repo",
            event_type="pull_request",
            payload=pull_request_payload(action="opened"),
            expected_repository="",
        )


@pytest.mark.parametrize(
    ("merged", "conclusion"),
    [(True, "merged"), (False, "rejected")],
)
def test_distinguishes_merged_and_rejected_pull_requests(
    merged: bool,
    conclusion: str,
) -> None:
    event = parse_github_event(
        delivery_id="delivery-2",
        event_type="pull_request",
        payload=pull_request_payload(action="closed", merged=merged),
        expected_repository=EXPECTED_REPOSITORY,
    )

    assert event.conclusion == conclusion
    assert event.merge_sha == ("merge-123" if merged else "")


@pytest.mark.parametrize("workflow_event", ["pull_request_target", "workflow_dispatch"])
def test_parses_correlated_workflow_completion(workflow_event: str) -> None:
    head_branch = (
        "sre/field20-checkout-incident-1"
        if workflow_event == "pull_request_target"
        else "main"
    )
    head_sha = "head-123" if workflow_event == "pull_request_target" else "merge-123"
    event = parse_github_event(
        delivery_id="delivery-3",
        event_type="workflow_run",
        payload={
            "action": "completed",
            "repository": repository(),
            "workflow_run": {
                "name": "Deliver Demo to AKS",
                "event": workflow_event,
                "head_branch": head_branch,
                "head_sha": head_sha,
                "conclusion": "success",
            },
        },
        correlation={
            "SreThreadId": "sre-thread-1",
            "TeamsThreadId": "incident-1",
            "PrNumber": 42,
            "PrUrl": "https://github.com/msftse/sre-agent-demo/pull/42",
            "HeadSha": "head-123",
            "MergeSha": "merge-123",
        },
        expected_repository=EXPECTED_REPOSITORY,
    )

    assert event.sre_thread_id == "sre-thread-1"
    assert event.teams_thread_id == "incident-1"
    assert event.conclusion == "success"
    assert event.head_sha == "merge-123"


def test_parses_correlated_demo_deployment_status() -> None:
    event = parse_github_event(
        delivery_id="delivery-5",
        event_type="deployment_status",
        payload={
            "action": "created",
            "repository": repository(),
            "deployment": {"environment": "demo", "sha": "merge-123"},
            "deployment_status": {"state": "in_progress"},
        },
        correlation={
            "SreThreadId": "sre-thread-1",
            "TeamsThreadId": "incident-1",
            "PrNumber": 42,
            "PrUrl": "https://github.com/msftse/sre-agent-demo/pull/42",
            "HeadSha": "head-123",
            "MergeSha": "merge-123",
        },
        expected_repository=EXPECTED_REPOSITORY,
    )

    assert event.event_type == "deployment_status"
    assert event.conclusion == "in_progress"


@pytest.mark.parametrize(
    ("event_type", "payload"),
    [
        (
            "pull_request",
            {
                **pull_request_payload(action="opened"),
                "repository": {"full_name": "other/repository"},
            },
        ),
        (
            "workflow_run",
            {
                "action": "completed",
                "repository": repository(),
                "workflow_run": {"name": "Other workflow"},
            },
        ),
        (
            "workflow_run",
            {
                "action": "completed",
                "repository": repository(),
                "workflow_run": {
                    "name": "Deliver Demo to AKS",
                    "event": "pull_request",
                    "head_branch": "main",
                    "head_sha": "merge-123",
                },
            },
        ),
        (
            "pull_request",
            {
                **pull_request_payload(action="opened"),
                "pull_request": {
                    **pull_request_payload(action="opened")["pull_request"],  # type: ignore[dict-item]
                    "head": {
                        "sha": "head-123",
                        "ref": "untrusted-branch",
                        "repo": repository(),
                    },
                },
            },
        ),
        (
            "deployment_status",
            {
                "action": "created",
                "repository": repository(),
                "deployment": {"environment": "production", "sha": "merge-123"},
                "deployment_status": {"state": "success"},
            },
        ),
    ],
)
def test_rejects_out_of_boundary_events(
    event_type: str,
    payload: dict[str, object],
) -> None:
    with pytest.raises(IgnoredGitHubEvent):
        parse_github_event(
            delivery_id="delivery-4",
            event_type=event_type,
            payload=payload,
            expected_repository=EXPECTED_REPOSITORY,
        )


def test_accepts_matching_colleague_fork_repository() -> None:
    expected_repository = "colleague/sre-agent-demo"
    payload = pull_request_payload(action="opened")
    payload["repository"] = repository(expected_repository)
    pull_request = payload["pull_request"]
    assert isinstance(pull_request, dict)
    pull_request["head"] = {
        **pull_request["head"],
        "repo": repository(expected_repository),
    }
    pull_request["base"] = {
        **pull_request["base"],
        "repo": repository(expected_repository),
    }

    event = parse_github_event(
        delivery_id="delivery-fork-1",
        event_type="pull_request",
        payload=payload,
        expected_repository=expected_repository,
    )

    assert event.repository == expected_repository
    assert event.head_sha == "head-123"


@pytest.mark.parametrize(
    ("payload_repository", "head_repository", "base_repository"),
    [
        ("msftse/sre-agent-demo", "colleague/sre-agent-demo", "colleague/sre-agent-demo"),
        ("colleague/sre-agent-demo", "msftse/sre-agent-demo", "colleague/sre-agent-demo"),
        ("colleague/sre-agent-demo", "colleague/sre-agent-demo", "other/sre-agent-demo"),
    ],
)
def test_rejects_mismatched_repositories_when_expected_is_colleague_fork(
    payload_repository: str,
    head_repository: str,
    base_repository: str,
) -> None:
    expected_repository = "colleague/sre-agent-demo"
    payload = pull_request_payload(action="opened")
    payload["repository"] = repository(payload_repository)
    pull_request = payload["pull_request"]
    assert isinstance(pull_request, dict)
    pull_request["head"] = {
        **pull_request["head"],
        "repo": repository(head_repository),
    }
    pull_request["base"] = {
        **pull_request["base"],
        "repo": repository(base_repository),
    }

    with pytest.raises(IgnoredGitHubEvent):
        parse_github_event(
            delivery_id="delivery-fork-2",
            event_type="pull_request",
            payload=payload,
            expected_repository=expected_repository,
        )