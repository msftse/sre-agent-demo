# Stage 17: Full Approval and Rejection Dress Rehearsal

## Goal

Exercise the complete live incident path from deterministic FIELD20 failures through Azure Monitor, Azure SRE Agent, Teams, an automatically created remediation pull request, explicit human rejection and merge decisions, protected deployment approval, verified recovery, and final RCA.

## Repeatable Browser Start

The current browser-led entry point is **Actions > Start Stage 17 incident > Run workflow**. Select **Confirm creation of the intentional FIELD20 regression PR**, then run the workflow.

The starter fails closed when a setup/remediation PR or delivery is already active. Otherwise it:

1. Verifies the known remediation commit remains in `main` history.
2. Creates `demo/stage17-incident-<run-id>` by inverting only that remediation.
3. Asserts that exactly the backend service and checkout test changed.
4. Opens a setup PR whose normal pull-request event starts `Validate source and chart` for its head commit.
5. Waits for the required check and automatically merges that setup PR only after validation succeeds.

The workflow dispatch authorizes the intentional source regression. The operator then performs one activation action in GitHub:

1. Approve the protected `demo` deployment, which deploys the setup merge SHA with deterministic traffic enabled.

Azure Monitor and Azure SRE Agent then take over. The agent investigates and creates `sre/field20-checkout-<incident-id>`. The operator reviews and merges that remediation PR and separately approves its protected recovery deployment. Recovery forces traffic off. The Helm test submits a valid FIELD20 checkout, verifies `29600 / 5920 / 0 / 23680`, and emits queryable trace evidence before the agent publishes the final Teams and PR RCA.

Repository prerequisite: configure secret `STAGE17_GITHUB_TOKEN` with an operator-scoped credential that can create and merge the generated setup PR in this repository. Organization policy blocks PR creation by the default workflow token. The starter waits for required validation and merges only its `demo/stage17-incident-*` setup PR. The later SRE remediation PR still requires human merge. Prefer a fine-grained token or GitHub App in production.

## Activation

The incident activation workflow deployed the prepared regression with deterministic traffic enabled. The first attempt correctly stopped when AKS was unavailable; after the cluster restarted, the approved retry deployed Helm revision 7 and started one traffic-generator replica.

The live application remained generally healthy while qualifying FIELD20 checkout returned HTTP 500. Azure Monitor fired Sev1 alert `NorthstarCheckoutFailureRatioHigh`, and the focused Autonomous response plan opened SRE thread `2c62d831-ed50-4311-b455-af18508d85e7`.

## Investigation and Remediation

Azure SRE Agent correlated Managed Prometheus, Log Analytics, Application Insights, AKS health, release metadata, deployed source, and a checkout trace. It proved that the fault was isolated to the explicit FIELD20 branch in `checkout()` while readiness endpoints, nodes, and pods remained healthy.

The agent created PR [#2](https://github.com/msftse/sre-agent-demo/pull/2) with two changes only:

- Remove the deliberate `discount_calculation_failed` HTTP 500 branch.
- Add a regression test for subtotal `29600`, discount `5920`, shipping `0`, and total `23680`.

The required source-and-chart validation passed. The agent had no review, merge, workflow-dispatch, deployment, or Azure-write capability.

## Human Decision Paths

The rejection path was exercised first. The user closed PR #2 without merging. The signed callback reported the rejection to the existing Teams and SRE threads, no deployment started, and the faulty workload remained active.

The user reopened the same PR. The signed callback restored the review-only state and validation passed again. Branch protection required CI, resolved conversations, linear history, and a user-performed merge; no separate approving review was required because the SRE connector authored the PR as the user account.

The user then merged PR #2. The signed callback stored merge SHA `2994903b44f5fa808cd13e1d6792b3c7ae040d62`, updated the existing incident timeline, and waited for separately authorized deployment.

## Recovery

The protected recovery workflow deployed merge SHA `2994903b44f5fa808cd13e1d6792b3c7ae040d62` only after the user approved the `demo` environment. Workflow run [31426062200](https://github.com/msftse/sre-agent-demo/actions/runs/31426062200) completed successfully.

Validated recovery evidence:

```text
Helm revision: 8, deployed
Backend replicas: 2/2 Ready
Frontend replicas: 2/2 Ready
Traffic generator: absent
FIELD20 checkout: confirmed
Subtotal: 29600
Discount: 5920
Shipping: 0
Total: 23680
Alert monitor condition: Resolved
```

The final RCA was posted to the existing Teams thread and PR #2. Azure SRE Agent did not perform any human-only action.

## Rehearsal Findings

The live exercise exposed and repaired four integration gaps:

- Deployment verification now evaluates only backend and frontend application deployments, allowing the optional traffic generator.
- Teams root notifications strip an old `;messageid=` suffix before creating a new channel thread.
- Azure investigation reads run serially to avoid concurrent command timeouts.
- A merged same-repository `sre/field20-checkout-*` PR now starts recovery automatically with traffic disabled; the protected environment still requires user approval. Manual dispatch remains available for incident activation and operator recovery.

Azure SRE Agent logging is also connected to the managed Application Insights component. Terraform applied one in-place agent update with zero additions or destroys and reports zero drift.

## Outcome

Stage 17 is complete. Detection, investigation, communication, automatic PR preparation, rejection, reopen, user merge, protected deployment approval, recovery verification, alert resolution, and final RCA were all proven against the live environment. The application is healthy on the merged fix and ready to be reset to a dormant regression baseline for a clean repeat E2E run.
