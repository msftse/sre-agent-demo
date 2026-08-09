---
name: northstar-checkout-remediation
description: Use for Northstar checkout HTTP 5xx incidents, FIELD20 discount failures, discount_calculation_failed errors, or the NorthstarCheckoutFailureRatioHigh alert on AKS.
tools:
  - RunAzCliReadCommands
  - northstar-github_search_code
  - northstar-github_get_file_contents
  - northstar-github_create_branch
  - northstar-github_push_files
  - northstar-github_create_pull_request
  - northstar-teams_post_incident_update
  - northstar-teams_reply_incident_thread
  - northstar-teams_get_incident_thread
---

# Northstar Checkout Remediation

Investigate and repair the deterministic Northstar checkout failure without changing Azure resources, merging code, or deploying releases.

## Scope

- Repository: `msftse/sre-agent-demo`
- Branch baseline: `main`
- Backend service: `Northstar Supply API`
- Alert: `NorthstarCheckoutFailureRatioHigh`
- Expected failure: valid `FIELD20` checkout returns HTTP 500 with `discount_calculation_failed`

Do not use this skill for unrelated checkout errors until evidence identifies the same path and failure contract.

## Runtime Resource Discovery

Never assume an Azure subscription, resource group, AKS cluster, namespace, workspace, Application Insights component, agent, or deployment name from a previous environment.

1. Read the subscription, alert-rule scope, affected resource IDs, labels, and dimensions from the active incident.
2. Resolve the monitored AKS cluster and resource group from those resource IDs and Azure Resource Graph relationships. If more than one cluster matches, stop and report the ambiguity.
3. Resolve the Kubernetes namespace, service, deployment, and pods from alert labels and matching Prometheus series. Confirm them against AKS inventory before querying logs.
4. Resolve linked Log Analytics, Azure Monitor workspace, and Application Insights resource IDs from the current AKS/monitoring configuration. Do not construct names from naming conventions.
5. Use only resources that belong to the incident scope. If required relationships cannot be proven, stop before source modification and report the missing context.

## Procedure

1. **Establish the incident window.** Record the alert start time, severity, affected resource, current status, and investigation/thread identifiers. Never assume the prepared demo defect is the live cause.
2. **Confirm impact from metrics.** Check `POST /api/checkout` request rate and 5xx ratio. Confirm unrelated routes and health probes remain healthy. Bound every query to the incident window.
3. **Check platform health.** Read the discovered AKS cluster, node, deployment, replica, pod, and probe state. If infrastructure is unhealthy, report that competing hypothesis before examining application code. Do not restart, scale, patch, or redeploy resources.
4. **Correlate logs.** Query `ContainerLogV2` in the discovered workspace and namespace for route `/api/checkout`, HTTP 500, and `error_code == "discount_calculation_failed"`. Capture timestamps, operation IDs, trace IDs, pod instances, Git SHA, and image digest. Do not include customer email or request bodies.
5. **Correlate traces and release.** Use Application Insights requests, dependencies, exceptions, and checkout spans to connect the failure to the same operation/trace IDs. Use `northstar_build_info` and `/api/release` evidence to identify the deployed Git SHA and image digest.
6. **Inspect source at the deployed revision.** Read `src/backend/app/service.py`, `src/backend/tests/test_api.py`, and relevant models/catalog code. Verify that discount validation accepts qualifying FIELD20 orders and that `checkout()` alone raises the explicit 500 error.
7. **State the root cause before editing.** The supported demo diagnosis is an explicit `FIELD20` branch in `checkout()` that raises `discount_calculation_failed` after a valid quote. If evidence differs, stop and report the mismatch; do not force the prepared fix.
8. **Design the smallest repair.** Add a regression test for two `field-pack-28` items with `FIELD20`. The expected totals are subtotal `29600`, discount `5920`, shipping `0`, and total `23680`. Then remove only the explicit 500 branch so `discount_cents = quote.discount_cents` runs for FIELD20 as it does for other valid discounts.
9. **Validate the proposed files.** Ensure the patch preserves invalid-discount handling, server-side repricing, free-shipping calculation, ordinary checkout, health endpoints, telemetry fields, and all existing tests. Do not modify alert thresholds, traffic generation, infrastructure, workflows, or credentials.
10. **Create the remediation change.** Create a unique branch named `sre/field20-checkout-<incident-or-thread-id>`. Push the source and regression-test changes in one coherent commit, then open a pull request to `main`. Include evidence, root cause, changed behavior, validation expectations, risk, and rollback notes.
11. **Stop at the pull request.** Never approve, merge, enable auto-merge, dispatch a workflow, deploy, or alter GitHub protection. Report the PR URL and wait for human review. Stage 15 response-plan instructions own mandatory Teams timeline behavior.

## Required Evidence

Before creating a branch, provide a compact evidence table with:

| Evidence | Required finding |
| --- | --- |
| Alert/metric | Checkout 5xx ratio and active request rate during the incident window |
| AKS | Nodes and backend replicas healthy, or a clearly stated competing platform issue |
| Logs | `discount_calculation_failed`, operation ID, trace ID, pod, release SHA, image digest |
| Traces | Checkout request/span correlated to the same operation or trace ID |
| Source | Exact deployed code path causing the failure |
| Test gap | No valid FIELD20 checkout regression test on the baseline revision |

## Pull Request Contract

- Base branch: `main`
- Change only the minimum backend source and test files required by evidence.
- Add the regression test before or in the same commit as the repair.
- Do not claim tests ran inside GitHub unless a check or tool result proves it.
- The PR body must state that merge requires human approval and deployment requires a separate protected-environment approval.
- If branch creation, file push, or PR creation fails, report the failed tool and preserve all gathered evidence; do not broaden permissions.

## Expected Output

Return:

1. Incident scope and current impact.
2. Evidence table with query windows and correlation identifiers.
3. Root cause and rejected alternatives.
4. Minimal repair and regression-test details.
5. Branch, commit, and pull-request links when created.
6. Explicit status: `Awaiting human PR review; no merge or deployment performed.`