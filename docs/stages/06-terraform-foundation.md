# Stage 6: Modular Terraform Foundation

## Goal

Create a validated, modular Terraform configuration for every planned Azure boundary without applying resources. This establishes naming, providers, dependencies, feature gates, identity, network, security, tags, and outputs before the destructive/cost-bearing Stage 7 apply checkpoint.

## State and Inputs

State is local by confirmed design. There is no `backend.tf`.

Ignored artifacts include:

- `.terraform/`
- `*.tfstate*`
- `*.tfplan`
- `terraform.tfvars*`
- `*.auto.tfvars*`

The safe `terraform.tfvars.example` remains tracked. Provide identity context through environment variables:

```bash
export TF_VAR_subscription_id="<subscription-id>"
export TF_VAR_tenant_id="<tenant-id>"
```

The verification script requires those values to match the active Azure CLI subscription and tenant before planning.

## Providers

| Provider | Constraint | Locked version | Purpose |
| --- | --- | --- | --- |
| AzureRM | `~> 4.81` | 4.81.0 | Supported Azure resources and RBAC |
| AzureAD | `~> 3.9` | 3.9.0 | Microsoft Entra context |
| AzAPI | `~> 2.11` | 2.11.0 | Azure SRE Agent preview/GA control-plane shape |
| random | `~> 3.9` | 3.9.0 | Persisted globally unique name suffix |

AzureRM 5.0 was available when this stage was built, but Microsoft Learn examples and the validated resource schemas target AzureRM 4.x. The major upgrade is deliberately deferred instead of silently adopting migration risk.

AzureRM automatic resource-provider registration is set to `none`. The resource-group module explicitly registers required providers, including AKS, ACR, Monitor, Insights, Dashboard, Managed Identity, Network, Policy Insights, and SRE Agent's `Microsoft.App`.

## Module Map

| Module | Default | Resources and responsibility |
| --- | --- | --- |
| `resource-group` | Enabled | Provider registrations and tagged resource group |
| `network` | Enabled | VNet, AKS subnet, NSG, reserved Standard public IP |
| `container-registry` | Enabled | Standard ACR with admin/anonymous access disabled |
| `aks` | Enabled | Two-node AKS Standard, Cilium overlay, Entra/Azure RBAC, OIDC/workload identity |
| `identities` | Enabled | GitHub Actions UAMI, protected-environment OIDC, ACR/AKS RBAC |
| `observability` | Disabled | Log Analytics, workspace-based App Insights, Azure Monitor workspace, Managed Grafana/RBAC |
| `sre-agent` | Disabled | AzAPI SRE Agent with Review/Low defaults and managed scope |

Observability is enabled in Stage 8. SRE Agent is enabled in Stage 11 after the product-specific capability and permission checks. Their HCL is still included in Stage 6 validation and full planning.

## Core Security Decisions

AKS uses:

- System-assigned managed identity and kubelet identity.
- Managed Microsoft Entra integration and Azure RBAC authorization.
- Local accounts disabled.
- OIDC issuer and workload identity enabled.
- Azure CNI Overlay and Cilium data plane/policy.
- No node public IPs.
- Host encryption and ephemeral Azure Linux OS disks.
- Azure Policy add-on.
- Key Vault CSI provider with two-minute automatic secret rotation.
- Automatic patch and NodeImage upgrades.
- Image cleaner every 48 hours.

GitHub OIDC subject:

```text
repo:msftse/sre-agent-demo:environment:demo
```

The identity receives only registry push and AKS deployment-related roles. The AKS kubelet identity receives `AcrPull`. No client secret is created.

ACR remains public because both the local workstation and GitHub-hosted runner must use `docker push`. Admin credentials and anonymous pull remain disabled. Images are tagged by Git SHA and deployed by registry digest.

## Mandatory Tags

Root tags are merged in this order:

1. User-supplied tags.
2. Mandatory project/environment/managed-by tags.
3. `SecurityControl=Ignore`.

Because mandatory values are merged last, callers cannot override the security-control tag. Both core and full plan JSON were checked for the tag on every taggable resource and the AKS system node pool.

After apply, run:

```bash
./scripts/audit-tags.sh \
  --resource-group "$(terraform -chdir=iac output -raw resource_group_name)" \
  --resource-group "$(terraform -chdir=iac output -raw aks_node_resource_group)"
```

This checks both the main resource group and AKS's platform-managed node resource group.

## Verification

Run without applying:

```bash
export TF_VAR_subscription_id="<subscription-id>"
export TF_VAR_tenant_id="<tenant-id>"
./scripts/verify-terraform.sh
```

The script performs:

1. Azure CLI subscription/tenant guard.
2. `terraform fmt -check -recursive`.
3. `terraform init -backend=false`.
4. Warning-free `terraform validate`.
5. Ephemeral Checkov install/run from the Microsoft PyPI proxy.
6. Core `-refresh=false` saved plan and JSON export.
7. Full-feature saved plan with observability and SRE Agent enabled.
8. Mandatory planned-tag audits.
9. Temporary plan cleanup.

Validated result:

```text
Terraform validate: passed, zero warnings
Checkov: 24 passed, 0 failed, 13 reasoned skips
Core plan: 27 creates, 0 changes, 0 destroys
Full plan: 33 creates, 0 changes, 0 destroys
Optional resources: 5 observability, 1 SRE Agent
Mandatory planned tags: passed
Azure resources applied: 0
```

The 13 Checkov skips record confirmed demo trade-offs rather than hiding them: public AKS/ACR for operator and GitHub-hosted access, Free AKS/no SLA, single region, Standard ACR, no CMK for synthetic stateless data, one small shared node pool, and Container Insights intentionally deferred to Stage 8.

## Stage 7 Checkpoint

Stage 7 must:

1. Set a deterministic suffix and review a saved core plan.
2. Present exact resource names and the 27 planned creates.
3. Obtain explicit approval before `terraform apply`.
4. Apply only the reviewed plan through Terraform.
5. Validate ACR, AKS, OIDC/RBAC, tags, and Terraform ownership.
6. Build locally and publish images with `docker push`; never use ACR build/import commands.
7. Install and test the Helm chart on the new AKS cluster.

## References

- [AKS workload identity with Terraform](https://learn.microsoft.com/azure/aks/workload-identity-deploy-cluster)
- [Azure CNI powered by Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)
- [Azure RBAC for AKS](https://learn.microsoft.com/azure/aks/manage-azure-rbac)
- [ACR managed identity authentication](https://learn.microsoft.com/azure/container-registry/container-registry-authentication-managed-identity)
- [Azure SRE Agent API reference](https://learn.microsoft.com/azure/sre-agent/api-reference)

## Outcome

Stage 6 passed without applying infrastructure. The core plan is ready for explicit Stage 7 review and approval.