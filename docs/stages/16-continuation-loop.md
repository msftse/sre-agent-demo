# Stage 16: GitHub-to-Agent-to-Teams Continuation Loop

## Goal

Resume the original Azure SRE Agent investigation after human GitHub decisions and protected deployment events. Preserve one SRE thread and one Teams timeline from alert through PR, merge/rejection, deployment, verification, and final RCA without giving the agent merge or workflow-dispatch authority.

## Signed GitHub Callback

The Teams bridge exposes `POST /api/github/events` through its existing FastAPI ASGI route. GitHub signs every payload with a dedicated HMAC secret stored in the bridge Key Vault as `github-webhook-secret`.

The endpoint:

- Requires `X-Hub-Signature-256` and uses constant-time comparison.
- Requires `X-GitHub-Delivery` for deduplication.
- Accepts only `pull_request`, `workflow_run`, and `deployment_status` events. Requested/in-progress workflow events and deployment-status events are acknowledged without downstream SRE work; terminal workflow completion is authoritative.
- Returns HTTP 401 for unsigned or invalid signatures.
- Returns HTTP 202 for valid but out-of-scope events such as GitHub `ping`.

`scripts/configure-github-webhook.sh` idempotently creates or updates exactly one repository hook for the configured target repository. The secret is read from Key Vault at runtime and never printed, committed, or stored in Terraform state.

## Trust Boundaries

A signed event is necessary but not sufficient because the repository can be public. Pull-request continuation also requires:

- Base repository equal to the configured target repository and base branch `main`.
- Head repository equal to the configured target repository (same-repository remediation only).
- Head branch beginning `sre/field20-checkout-`.
- Exactly one hidden `<!-- sre-thread-id: ... -->` marker in the PR body.

Workflow continuation requires the exact `Deliver Demo to AKS` workflow, a trusted `workflow_dispatch` or merged-PR `pull_request_target` event, and the `main` head branch. The automatic workflow itself also requires a merged same-repository `sre/field20-checkout-*` PR and forces incident traffic off. Deployment continuation requires the `demo` environment. All post-merge events must match a merge SHA previously stored from the correlated PR.

## Durable Correlation

The existing Azure Table Storage state now stores:

| Partition | Purpose |
| --- | --- |
| `investigation` | Existing SRE thread to Teams root activity mapping |
| `pull-request` | PR number to SRE thread, PR URL, head SHA, and merge SHA |
| `merge-sha` | Merge SHA to PR and SRE thread lookup |
| `github-delivery` | GitHub delivery ID plus per-destination completion flags |
| `alert-monitor` | Merge SHA to the one GitHub delivery allowed to start alert monitoring |

Accepted terminal events are processed by `github_continuation_orchestrator` with Durable activity retries. `TeamsSent` and `SreSent` are marked independently, so retries continue only the missing destination instead of duplicating a completed Teams or SRE message.

## Continuation Flow

1. The Stage 14 skill embeds the current SRE thread marker in the agent-authored PR body.
2. PR opened/reopened events map the PR to the existing SRE and Teams threads and report the human-review wait state.
3. PR closed without merge reports rejection and stops.
4. Human merge stores the merge SHA and reports that protected deployment is still pending.
5. Terminal workflow completion correlated by merge SHA reports failure/cancellation or successful deployment. Transient and redundant deployment events do not wake SRE.
6. Successful recovery starts one `alert_resolution_orchestrator` instance keyed by merge SHA. It polls the exact alert every 30 seconds for 30 minutes and extends once for 10 minutes.
7. On `Resolved`, the bridge appends trusted merge, PR, workflow, and alert evidence to the original SRE thread. The checked-in Helm test's successful workflow result proves HTTP 200 and exact total assertions passed.
8. The agent independently verifies deployed SHA/digest, replicas, FIELD20 telemetry, residual failures, and alert resolution.
9. The agent adds one canonical RCA comment to the existing PR and posts the identical body to the existing Teams thread. If monitoring or finalization times out, Teams receives one manual-check message and no RCA is claimed.

## GitHub Tool Boundary

The `northstar-github` allowlist now contains seven tools:

- `search_code`
- `get_file_contents`
- `pull_request_read`
- `create_branch`
- `push_files`
- `create_pull_request`
- `add_issue_comment`

`pull_request_read` verifies callback-reported state and `add_issue_comment` publishes the final RCA. Merge, review, PR mutation, branch update, workflow dispatch, and deployment tools remain unavailable.

## Deployment

Terraform keeps the Key Vault reference named `GITHUB_WEBHOOK_SECRET` and adds a subscription-scoped custom alert-reader role containing only `Microsoft.AlertsManagement/alerts/read`. It never manages the webhook secret value.

`scripts/deploy-teams-bridge.sh` now:

1. Requires all three bridge secrets.
2. Publishes the Function code.
3. Removes an empty classic `AzureWebJobsStorage` connection string synthesized by Core Tools, which otherwise overrides managed-identity storage settings.
4. Verifies the legacy key is absent and restarts the host.
5. Health-checks the Function.
6. Configures SRE capabilities and the GitHub webhook.

The first Stage 16 publish exposed this Core Tools behavior with `AccountKey` empty. Removing the injected key and restarting restored the host. The hardened deployment then completed end to end.

Final live qualification exposed two additional worker-lifecycle details. The installed Durable SDK returns a non-null status object with an empty `runtime_status` for a missing instance, so orchestration startup must treat that result as not found. A GitHub delivery activity can also run on a fresh worker that has never initialized the Teams SDK through the HTTP path, so the activity initializes Teams before proactive delivery. Both cases have focused regression tests.

## Validation

Validated outcomes:

- Ruff and strict mypy passed.
- 134 bridge tests passed, including HMAC rejection, event boundaries, merge/rejection, deployment/workflow correlation, delivery deduplication, asymmetric retry resumption, alert polling, 30+10-minute virtual timing, SRE finalization, missing-instance startup, fresh-worker Teams initialization, and SRE message payloads.
- Unsigned live webhook request returned 401.
- GitHub-signed terminal redeliveries returned 202 and started one deterministic monitor for the correlated recovery merge SHA.
- Exactly one active hook exposes exactly three event types.
- Function uses a Key Vault secret reference and has no classic storage override.
- Function host is healthy and all 15 Functions are registered.
- The feature-scoped Terraform plan reports zero changes. A separate refreshed full plan identified only 14 pre-existing tag updates outside the Teams bridge; they were not mixed into this feature.
- GitHub connector has exactly seven allowed tools; forbidden merge/review/mutation tools remain absent.
- Checkout skill has eleven tools and matches repository source.
- Required GitHub validation passed on exact qualified feature source, branch protection remained enforced, and auto-merge remained disabled during qualification.
- An immediate-resolved rehearsal reused an existing SRE thread, Teams incident thread, and PR and delivered byte-identical 6,624-character RCA bodies.
- A fresh end-to-end rehearsal fired the checkout alert, created a human-merged remediation PR, deployed recovery with traffic disabled, observed `Resolved`, and completed the deterministic monitor with status `finalized` on the same SRE thread.
- In the fresh rehearsal, `add_issue_comment` and `reply_incident_thread` completed once against the existing destinations with byte-identical 6,840-character RCA bodies. The Function supplied trusted continuation evidence but did not author the RCA.
- Incident traffic is disabled and no checkout alert remains fired.

## Outcome

Stage 16 is complete and qualified end to end. Verified GitHub decisions and delivery events resume the exact SRE investigation and Teams timeline without weakening the human remediation-merge boundary or main-only deployment restriction. Alert resolution now reliably completes the existing incident with an SRE-authored canonical RCA rather than requiring a second PR, thread, or Function-authored summary.