# Stage 11: Azure SRE Agent Foundation

## Goal

Deploy Azure SRE Agent with native Azure Monitor incident discovery and enough read access to investigate the Northstar workload, without granting Azure remediation permissions or activating the dormant checkout incident.

## Deployed Agent

Terraform manages `sre-sre-agent-demo-demo-ij2608` through `Microsoft.App/agents@2026-01-01`. The live agent is `Running` with provisioning state `Succeeded` at:

```text
https://sre-sre-agent-demo-demo-ij2608--ba3ee979.bb5fab60.swedencentral.azuresre.ai
```

The agent has these control-plane settings:

| Setting | Value | Purpose |
| --- | --- | --- |
| Global mode | `Review` | Safe fallback for Azure infrastructure writes |
| Access level | `Low` | Reader-level managed-resource access |
| Incident platform | `AzMonitor` | Native subscription alert scanning |
| Upgrade channel | `Stable` | Stable feature channel |
| Managed resources | Demo resource group | Limits investigation context |
| Sandbox/VNet | None | VNet integration remains out of scope |

Response-plan autonomy is separate from the global fallback. Stage 15 will create a narrowly matched Autonomous checkout plan so GitHub branch, commit, and pull-request creation can proceed without approval. GitHub permissions, tool access policy, branch protection, and the protected deployment environment remain the hard boundaries: the agent must not merge or deploy.

## Identity and RBAC

The 2026 API requires a dedicated user-assigned managed identity in both `actionConfiguration.identity` and `knowledgeGraphConfiguration.identity`. The agent retains its platform system identity, but resource investigation uses `id-sre-sre-agent-demo-demo-ij2608`.

The UAMI receives exactly:

| Scope | Role |
| --- | --- |
| Subscription | Monitoring Contributor |
| Demo resource group | Reader |
| Demo resource group | Monitoring Reader |
| Demo resource group | Log Analytics Reader |
| AKS cluster | Azure Kubernetes Service Cluster User Role |
| AKS cluster | Azure Kubernetes Service RBAC Reader |

Subscription-scoped Monitoring Contributor is required by the native Azure Monitor scanner to acknowledge and synchronize alert lifecycle state. The identity has no Contributor, Owner, AKS administrator, or general Azure mutation role. The configured operator receives SRE Agent Administrator on the agent resource only.

## Native Alert Discovery

Azure SRE Agent scans Azure Monitor every minute for alerts in subscriptions where its UAMI has Monitoring Contributor. The checkout Prometheus rule therefore has no action group. This avoids a misleading no-op routing resource and keeps Azure Monitor as the source of truth.

Direct ARM creation connected `AzMonitor` without creating a quickstart response plan. The data-plane collection `/api/v2/extendedAgent/incidentfilters` is empty, so no default plan can start a duplicate or premature investigation. Stage 15 will add the dedicated plan after Teams, GitHub, and the Northstar checkout skill are configured.

## Deployment Note

The first agent PUT returned `InvalidIdentity` because the initial payload omitted `knowledgeGraphConfiguration.identity`. Live 2026 resource inspection confirmed that Azure SRE Agent uses a UAMI resource ID for action and knowledge access. Terraform was corrected to create and attach that UAMI before the agent, then a zero-destroy recovery plan completed successfully.

## Verification

Validated after apply:

```text
Terraform: 39 resources, zero drift
Checkov: 24 passed, 0 failed, 13 reasoned skips
Agent: Succeeded, Running, Stable, AzMonitor
Agent data plane: reachable with https://azuresre.dev token audience
Threads: 0
Incident response plans: 0
Connectors/custom agents/plugins: 0
Checkout alert instances: 0
AKS: backend 2/2, frontend 2/2, all four pods Ready
Traffic generator: disabled
```

## Outcome

Stage 11 is complete. Azure SRE Agent can discover Azure Monitor incidents and read Northstar resources and telemetry, but no response plan or source-code/Teams connector exists yet. The deterministic incident remains dormant for the later end-to-end exercise.