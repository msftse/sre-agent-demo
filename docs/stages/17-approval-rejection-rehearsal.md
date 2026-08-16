# Stage 17: Full Approval and Rejection Dress Rehearsal

## Goal

Exercise the complete live incident path from deterministic FIELD20 failures through Azure Monitor, Azure SRE Agent, Teams, an automatically created remediation pull request, explicit human rejection and merge decisions, automatic main-only deployment, verified recovery, and final RCA.

## Repeatable Browser Start

The current browser-led entry point is **Actions > Start Demo > Run workflow**. Select **Confirm direct publication of the intentional FIELD20 regression to main**, then run the workflow.

The starter fails closed when any PR or delivery is already active. Otherwise it:

1. Discovers the latest merged `sre/field20-checkout-*` remediation and verifies its merge commit remains in `main` history. On the first run in a fork, where upstream PR records are not inherited, it resolves the latest FIELD20 remediation from inherited first-parent Git history instead.
2. Creates one local incident commit by inverting only that remediation.
3. Asserts that exactly the backend service and checkout test changed.
4. Runs Ruff, strict mypy, and the backend test suite against the intentional regression.
5. Temporarily applies `routine` protection, pushes the commit directly to `main`, and restores `incident-demo` protection even on failure.
6. Dispatches `Deliver Demo to AKS` with the exact incident SHA and traffic enabled.

The workflow dispatch authorizes the intentional source regression and its automatic deployment through the main-only `demo` environment.

Azure Monitor and Azure SRE Agent then take over. The agent investigates and creates `sre/field20-checkout-<incident-id>`. The operator reviews and merges that remediation PR. `Deliver Demo to AKS` starts recovery automatically. Recovery forces traffic off, deploys the remediation merge SHA, and returns the application to service. The Helm test submits a valid FIELD20 checkout, verifies `29600 / 5920 / 0 / 23680`, and emits queryable trace evidence. The successful delivery callback resumes the SRE Agent, which verifies alert recovery and publishes the final Teams and PR RCA.

Repository prerequisite: configure secret `STAGE17_GITHUB_TOKEN` with an operator-scoped credential that can update branch protection, push to `main`, and dispatch Actions in this repository. The later SRE remediation PR is the only PR and still requires human merge. Prefer a fine-grained token or GitHub App in production.

Fork note: any PR numbers, run IDs, commit SHAs, and links in this stage are historical evidence from the canonical rehearsal and are not reusable inputs. In a fork run, use the artifacts generated in your own repository.

## Activation

The incident activation workflow deployed the prepared regression with deterministic traffic enabled. The first attempt correctly stopped when AKS was unavailable; after the cluster restarted, the approved retry deployed Helm revision 7 and started one traffic-generator replica.

The live application remained generally healthy while qualifying FIELD20 checkout returned HTTP 500. Azure Monitor fired Sev1 alert `NorthstarCheckoutFailureRatioHigh`, and the focused Autonomous response plan opened an SRE thread `<historical-sre-thread-id>`.

## Investigation and Remediation

Azure SRE Agent correlated Managed Prometheus, Log Analytics, Application Insights, AKS health, release metadata, deployed source, and a checkout trace. It proved that the fault was isolated to the explicit FIELD20 branch in `checkout()` while readiness endpoints, nodes, and pods remained healthy.

The agent created PR `<historical-pr-number>` with two changes only:

- Remove the deliberate `discount_calculation_failed` HTTP 500 branch.
- Add a regression test for subtotal `29600`, discount `5920`, shipping `0`, and total `23680`.

The required source-and-chart validation passed. The agent had no review, merge, workflow-dispatch, deployment, or Azure-write capability.

## Human Decision Paths

The rejection path was exercised first. The user closed the remediation PR without merging. The signed callback reported the rejection to the existing Teams and SRE threads, no deployment started, and the faulty workload remained active.

The user reopened the same PR. The signed callback restored the review-only state and validation passed again. Branch protection required CI, resolved conversations, linear history, and a user-performed merge; no separate approving review was required because the SRE connector authored the PR as the user account.

The user then merged the remediation PR. The signed callback stored merge SHA `<historical-merge-sha>`, updated the existing incident timeline, and waited for separately authorized deployment.

## Recovery

The protected recovery workflow deployed merge SHA `<historical-merge-sha>` only after the user approved the `demo` environment. Workflow run `<historical-workflow-run-id>` completed successfully.

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

The final RCA was posted to the existing Teams thread and remediation PR. Azure SRE Agent did not perform any human-only action.

## Rehearsal Findings

The live exercise exposed and repaired four integration gaps:

- Deployment verification now evaluates only backend and frontend application deployments, allowing the optional traffic generator.
- Teams root notifications strip an old `;messageid=` suffix before creating a new channel thread.
- Azure investigation reads run serially to avoid concurrent command timeouts.
- A merged same-repository `sre/field20-checkout-*` PR starts recovery automatically with traffic disabled; the `demo` environment has no reviewer gate and accepts only `main`. Manual dispatch remains available for incident activation and operator recovery.

Azure SRE Agent logging is also connected to the managed Application Insights component. Terraform applied one in-place agent update with zero additions or destroys and reports zero drift.

## Outcome

Stage 17 is complete. Detection, investigation, communication, automatic PR preparation, rejection, reopen, user merge, automatic main-only deployment, recovery verification, alert resolution, and final RCA were all proven against the live environment. The application is healthy on the merged fix and ready to be reset to a dormant regression baseline for a clean repeat E2E run.
