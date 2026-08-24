# Stage 11: Azure SRE Agent Foundation

## Goal

Deploy Azure SRE Agent with native Azure Monitor incident discovery and enough read access to investigate the Northstar workload, without granting Azure remediation permissions or activating the dormant checkout incident.

## Deployed Agent

Terraform manages the generated agent through `Microsoft.App/agents@2026-01-01`. Retrieve the current resource ID, endpoint, and identity IDs with:

```bash
terraform -chdir=iac output -json sre_agent | jq
```

After deployment, the agent must report `Running` with provisioning state `Succeeded` and its generated endpoint must be reachable.

The agent has these control-plane settings:

| Setting | Value | Purpose |
| --- | --- | --- |
| Global mode | `Review` | Safe fallback for Azure infrastructure writes |
| Access level | `Low` | Reader-level managed-resource access |
| Incident platform | `AzMonitor` | Native subscription alert scanning |
| Upgrade channel | `Stable` | Stable feature channel |
| Managed resources | Demo resource group | Limits investigation context |
| Sandbox/VNet | None | VNet integration remains out of scope |

Response-plan autonomy is separate from the global fallback. Stage 15 created a narrowly matched Autonomous checkout plan so GitHub branch, commit, and pull-request creation can proceed without approval. GitHub permissions, tool access policy, branch protection, and the protected deployment environment remain the hard boundaries: the agent must not merge or deploy.

## Identity and RBAC

The 2026 API requires a dedicated user-assigned managed identity in both `actionConfiguration.identity` and `knowledgeGraphConfiguration.identity`. The agent retains its platform system identity, but resource investigation uses the identity ID in the nested `sre_agent` Terraform output.

The UAMI receives exactly:

| Scope | Role |
| --- | --- |
| Subscription | Monitoring Contributor |
| Demo resource group | Reader |
| Demo resource group | Monitoring Reader |
| Demo resource group | Log Analytics Reader |
| AKS cluster | Azure Kubernetes Service Cluster User Role |
| AKS cluster | Azure Kubernetes Service RBAC Reader |
| AKS cluster | Custom role: `Microsoft.ContainerService/managedClusters/nodes/read` only |

Subscription-scoped Monitoring Contributor is required by the native Azure Monitor scanner to acknowledge and synchronize alert lifecycle state. Cluster User retrieves user kubeconfig, and RBAC Reader covers namespace-scoped workload objects and node metrics. RBAC Reader does not include the core cluster-scoped Node data action used by `kubectl get nodes`, so the custom role adds exactly that read and nothing else. The identity has no Contributor, Owner, AKS administrator, Kubernetes write, secret-read, exec, RBAC-mutation, or general Azure mutation role. The configured operator receives SRE Agent Administrator on the agent resource only.

## Native Alert Discovery

Azure SRE Agent scans Azure Monitor every minute for alerts in subscriptions where its UAMI has Monitoring Contributor. The checkout Prometheus rule therefore has no action group. This avoids a misleading no-op routing resource and keeps Azure Monitor as the source of truth.

Direct ARM creation connected `AzMonitor` without creating a quickstart response plan. Stage 15 added one dedicated checkout filter after Teams, GitHub, and the Northstar checkout skill were configured. No default quickstart plan exists, preventing duplicate investigations.

## Deployment Note

The first agent PUT returned `InvalidIdentity` because the initial payload omitted `knowledgeGraphConfiguration.identity`. Live 2026 resource inspection confirmed that Azure SRE Agent uses a UAMI resource ID for action and knowledge access. Terraform was corrected to create and attach that UAMI before the agent, then a zero-destroy recovery plan completed successfully.

A later live investigation showed an OBO permission card for `kubectl get nodes -o wide` even though Cluster User and RBAC Reader were assigned. Inspection of the live built-in role proved it contains `metrics.k8s.io/nodes/read` but not `managedClusters/nodes/read`. Terraform now supplies the missing read as a dedicated AKS-scoped custom role. Azure RBAC propagation can take several minutes; cancel any OBO card created before propagation and retry in the same thread rather than granting operator credentials.

## Verification

Validated after apply:

```text
Terraform: zero drift; tracked count recorded from the current state
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

The node-read correction was separately validated with Checkov `30 passed, 0 failed`, an exact two-create/zero-destroy plan, live role/assignment inspection, and a zero-change feature plan after apply. A fresh isolated SRE diagnostic then completed `kubectl get nodes -o wide`, returned managed-identity output, reported no error, and created no approval or OBO record.

## Outcome

Stage 11 is complete. Azure SRE Agent can discover Azure Monitor incidents and read Northstar resources and telemetry, but no response plan or source-code/Teams connector exists yet. The deterministic incident remains dormant for the later end-to-end exercise.