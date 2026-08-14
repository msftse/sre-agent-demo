# Stage 14: Northstar Checkout Remediation Skill

## Goal

Install a reusable Azure SRE Agent custom skill that investigates the Northstar checkout alert, proves the FIELD20 root cause from live evidence, prepares the minimum source-and-test repair, and creates a pull request without merging or deploying it.

## Runtime Ownership

The skill runs only inside Azure SRE Agent. Its deployment source is stored at `azure-sre-agent/sre-agent-skills/northstar-checkout-remediation.md`, outside `.github/skills`, so GitHub Copilot and repository agents do not discover or execute it as a project skill.

`scripts/configure-sre-checkout-skill.sh` composes that source with `azure-sre-agent/templates/northstar-checkout-rca.md` and sends the result to the current agent's `/api/v2/extendedAgent/skills/northstar-checkout-remediation` data-plane resource. The script derives the agent ID and endpoint from Terraform outputs and verifies that the active Azure CLI subscription matches the resource ID. It contains no fixed tenant, subscription, resource group, agent, cluster, workspace, or namespace identifier.

## Runtime Discovery

Each new environment can use different Azure names and IDs. The skill therefore requires the agent to:

1. Read subscription, alert scope, affected resource IDs, labels, and dimensions from the active incident.
2. Resolve the AKS cluster and resource group from Azure resource relationships.
3. Resolve namespace, service, deployment, and pods from alert labels and matching Prometheus series.
4. Resolve linked Log Analytics, Azure Monitor workspace, and Application Insights IDs from live monitoring configuration.
5. Stop on ambiguity instead of constructing names from conventions.

Stable application facts remain explicit: repository, alert name, route, error code, FIELD20 input, expected totals, source path, test path, and human approval boundaries.

## Attached Tools

The skill initially received nine tools. Stage 16 added PR-state read and final-RCA comment capabilities, so it now receives eleven tools only while active:

- Read-only Azure CLI investigation.
- GitHub code search, file/PR read, branch creation, multi-file push, pull-request creation, and issue/PR commenting.
- Teams root post, threaded reply, and route lookup.

It has no GitHub merge, review, workflow dispatch, deployment, or Azure write tool.

## Automatic Deployment

`scripts/configure-sre-agent-capabilities.sh` is the post-deployment bootstrap. It runs these idempotent steps in dependency order:

1. Configure `northstar-teams`.
2. Configure `northstar-github`.
3. Upsert `northstar-checkout-remediation`.
4. Verify the live skill content and exact eleven-tool assignment.

`scripts/deploy-teams-bridge.sh` invokes this bootstrap after the Function health check. A fresh environment therefore installs both connectors and the skill without SRE portal configuration. The operator must already be signed in to the Terraform subscription with Azure CLI and to the intended GitHub account with GitHub CLI.

## Repair Contract

The skill must correlate the incident window across metrics, AKS health, `ContainerLogV2`, Application Insights, release SHA, image digest, and deployed source before editing. If the evidence matches the prepared defect, it adds a valid FIELD20 regression test and removes only the explicit 500 branch.

The expected checkout for two `field-pack-28` items is:

| Value | Cents |
| --- | ---: |
| Subtotal | 29600 |
| Discount | 5920 |
| Shipping | 0 |
| Total | 23680 |

The skill stops after opening the PR and returns `Awaiting human PR review; no merge or deployment performed.`

## RCA Contract

After a successful human merge and recovery deployment, the skill renders the bundled canonical template. It preserves every heading, uses UTC timestamps, replaces unsupported values with `Not observed` or `Not applicable`, and publishes the same rendered body to the PR and Teams. Status is `Resolved` only when alert, release, workload, FIELD20 checkout, telemetry, and human-decision evidence all pass; otherwise the skill posts a concise deferred update and withholds the final RCA.

## Validation

`scripts/verify-checkout-skill.sh` checks:

- Front matter and all nine tool names.
- Absence of environment-specific Azure identifiers.
- Runtime resource-discovery instructions.
- FIELD20 input and expected totals.
- Canonical RCA template headings and rendering rules.
- Merge and deployment stop clauses.
- Exact byte-for-byte equality between composed skill/template source and live `properties.skillContent`.

The unified bootstrap ran twice successfully. Stage 16 later verified the live skill with eleven tools and matching content. No incident, branch, commit, pull request, workflow, or deployment was started during Stage 14.

## Outcome

Stage 14 is complete. Every bridge deployment now configures the current SRE Agent's connectors and portable checkout remediation skill automatically. Stage 15 extended that same bootstrap with the narrowly matched autonomous incident responder, mandatory Teams timeline, and response plan.