# Stage 15: Incident Responder and Response Plan

## Goal

Automatically route only the prepared severity-1 Northstar checkout alert to a focused custom responder. Let the responder investigate and create a remediation pull request without approval, while requiring a Teams incident timeline and preserving human-only merge and deployment authorization.

## Custom Responder

Azure SRE Agent custom responder `northstar-checkout-responder` is deployed from `azure-sre-agent/subagents/sre-agent-responders/northstar-checkout-responder.md`.

The responder has:

- No direct tools.
- Skills enabled.
- Exactly one allowed skill: `northstar-checkout-remediation`.
- No handoffs.

The Stage 14 skill supplies its temporary tools only when loaded. Stage 16 extended that skill to eleven tools for PR-state verification and final RCA comments. This prevents the responder from bypassing the skill procedure while retaining read-only Azure investigation, constrained GitHub operations, and fixed-destination Teams updates.

## Mandatory Teams Timeline

The responder must create one Teams root post before any source write. The post includes incident identity, severity, fired time, affected scope, SRE thread reference, and `Investigation started` status.

Material milestones use replies in the same thread:

1. Impact and platform-health confirmation.
2. Evidence-backed root cause or competing hypothesis.
3. Repair branch and validation scope.
4. Pull-request URL and human approval status.
5. Failure/blocker or completed RCA.

Completed RCAs use the canonical template bundled by `northstar-checkout-remediation`. GitHub and Teams receive the same rendered headings and evidence; incomplete alert or recovery evidence produces a deferred status instead of an ad hoc success summary.

If the initial Teams post fails after one retry, the responder may continue read-only evidence collection but must not create a branch, commit, or PR. It reports the notification-boundary failure and stops.

## Response Plan

Active response plan `northstar-checkout-response` uses:

| Setting | Value |
| --- | --- |
| Incident platform | Azure Monitor |
| Severity | `Sev1` only |
| Title contains | `NorthstarCheckoutFailureRatioHigh` |
| Responder | `northstar-checkout-responder` |
| Mode | `Autonomous` |
| Recurrence merge | Disabled |

The exact title plus severity filter prevents unrelated alerts from using the autonomous path. Recurrence merging is disabled so every repeatable demo run creates a fresh investigation and invokes the responder, even when a previous incident was resolved recently.

No default `quickstart_handler` exists, so the checkout alert cannot be processed twice.

## Approval Boundary

Autonomy ends after GitHub branch, commit, and PR creation. The responder and skill prohibit:

- PR approval, merge, or auto-merge.
- Workflow dispatch or deployment.
- Azure restart, scale, patch, or configuration writes.
- Alert-rule and GitHub-protection changes.

The Stage 9 incident-demo branch protection enforces human remediation merge; the `demo` environment restricts automatic deployment to `main`.

## Automatic Deployment

`scripts/configure-sre-agent-capabilities.sh` now configures resources in this order:

1. Teams connector.
2. GitHub connector.
3. Checkout skill and live skill verification.
4. Checkout responder.
5. Checkout response plan and live plan verification.

`scripts/deploy-teams-bridge.sh` runs this bootstrap after Function health succeeds. Fresh environments therefore receive the complete incident-response configuration without portal work.

## Validation

`scripts/verify-checkout-response-plan.sh` verifies:

- Responder content exactly matches repository source.
- No direct tools and only the Stage 14 skill is allowed.
- Mandatory Teams timeline and failure boundary clauses.
- Canonical RCA-template requirement for completed incidents.
- Active `Autonomous` mode.
- Exact `Sev1` and alert-title match.
- Recurrence merging disabled for distinct investigations.
- Exactly one response filter and no quickstart or obsolete handler.

The full capability bootstrap ran twice successfully. Bridge lint/type/tests/package validation passed with 13 tests. At completion, deterministic traffic remained disabled and zero checkout alerts were active, so no investigation, branch, commit, PR, workflow, or deployment was triggered.

## Outcome

Stage 15 is complete. The dormant checkout incident now has a focused autonomous responder, mandatory Teams timeline, portable skill, and human-governed source/deployment boundaries. Stage 16 subsequently implemented the post-PR continuation loop for merge detection, protected deployment, verification, and final Teams/GitHub RCA.