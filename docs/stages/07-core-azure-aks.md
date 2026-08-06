# Stage 7: Core Azure and AKS Platform

## Goal

Provision the approved core Azure platform with Terraform, publish the application images from the local Docker daemon, and prove the hardened Helm workload on AKS before adding observability.

## Provisioned Platform

| Component | Name or value |
| --- | --- |
| Resource group | `rg-sre-agent-demo-demo-ij2608` |
| Region | Sweden Central |
| AKS | `aks-sre-agent-demo-demo-ij2608` |
| AKS node resource group | `MC_rg-sre-agent-demo-demo-ij2608_aks-sre-agent-demo-demo-ij2608_swedencentral` |
| ACR | `acrsreagentdemodemoij2608` |
| VNet | `vnet-sre-agent-demo-demo-ij2608` |
| Reserved ingress IP | `4.223.157.176` |
| GitHub Actions identity | `id-github-sre-agent-demo-demo-ij2608` |
| Helm release | `northstar`, revision 2, namespace `northstar` |

The AKS system pool contains two `Standard_D2ds_v5` Azure Linux 3 nodes. Both reported `Ready` on Kubernetes `v1.35.6`. Host encryption, OIDC, workload identity, managed Entra authentication, Azure RBAC, Cilium, and the hardened settings defined in Stage 6 are enabled.

## Terraform Apply

The deterministic ignored configuration uses suffix `ij2608`. Shared provider registrations remain outside environment state and are validated as subscription prerequisites. AKS host encryption also requires the subscription feature:

```text
Microsoft.Compute/EncryptionAtHost = Registered
```

The initial AKS create stopped before cluster creation because this feature was not registered. After explicit approval, the feature was registered and the Microsoft.Compute provider refreshed. The replacement saved plan was reviewed by checksum and contained exactly four creates: AKS and its three dependent RBAC assignments.

Azure added `FirstPartyUsage=/Unprivileged` to the reserved public IP. Removing this platform-owned metadata would replace the IP, so the network module ignores `ip_tags` while retaining Terraform ownership of the address and all configured tags.

A second approved saved plan added one optional, cluster-scoped `Azure Kubernetes Service RBAC Cluster Admin` assignment for the configured human operator. Subscription `Owner` alone does not grant Kubernetes data-plane access, and local accounts remain disabled. Reusable environments default `aks_operator_object_id` to `null`; this ignored demo configuration opts in with the operator's immutable Entra object ID.

Final Terraform result:

```text
16 resources tracked
No changes. Your infrastructure matches the configuration.
0 resources destroyed
```

## Images

Both images were built for `linux/amd64` on the local Docker daemon and published with `docker push`. No ACR build, import, or task command was used.

| Image | Git tag | Immutable digest |
| --- | --- | --- |
| `northstar/backend` | `4b78b371d14a` | `sha256:2b688a788d00e8212fe57508478da7c0b565e0ac8ade5ca2540595a9196fbf8a` |
| `northstar/frontend` | `4b78b371d14a` | `sha256:77e36a6e7ee9844175f59506602531deac72b77086daad5e411051b232a08249` |

ACR returned the same digests before Helm installation. AKS pulls through its kubelet identity and cluster-scoped `AcrPull` assignment.

## Helm Deployment

The `northstar` release runs two backend and two frontend replicas by digest. The namespace enforces, audits, and warns at the Kubernetes Restricted Pod Security level. Both deployments retain non-root execution, `RuntimeDefault` seccomp, read-only root filesystems, disabled service-account token mounts, disabled service links, and dropped Linux capabilities.

Managed Prometheus discovery was installed with `serviceMonitor.enabled=false` because the CRD and Azure Monitor workspace arrive in Stage 8. The application currently uses ClusterIP services; the reserved public IP is not attached to an ingress controller yet.

Live Cilium testing exposed a missing identity on the Helm smoke-test pod: the backend NetworkPolicy correctly required release selector labels, but the test pod originally carried only generic chart labels. The test template now includes the release name and instance labels, allowing only the chart's own test identity through the dedicated backend rule.

## Verification

Validated outcomes:

```text
AKS provisioning state: Succeeded
AKS power state: Running
System nodes: 2/2 Ready
Host encryption: enabled
Required ACR and AKS role assignments: present
Helm release: deployed, revision 2
Backend replicas: 2/2 ready
Frontend replicas: 2/2 ready
Helm smoke test: Succeeded
PodDisruptionBudgets: 2
NetworkPolicies: 2
Restricted namespace labels: passed
Terraform drift: none
SecurityControl=Ignore: 13 live resources across both resource groups
```

The Helm test verifies backend `/health/ready` and frontend `/healthz` through the live ClusterIP services. A local port-forward also returned the Northstar storefront with HTTP 200, and `/api/release` reported Git SHA `4b78b371d14a` in environment `demo`.

To review the deployed application:

```bash
export KUBECONFIG="${TMPDIR}/sre-agent-demo-kubeconfig"
az aks get-credentials \
  --resource-group rg-sre-agent-demo-demo-ij2608 \
  --name aks-sre-agent-demo-demo-ij2608 \
  --file "$KUBECONFIG" \
  --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl port-forward --namespace northstar \
  service/northstar-sre-demo-frontend 8080:8080
```

Open `http://127.0.0.1:8080/`.

## Outcome

Stage 7 is complete. Core Azure infrastructure, AKS access, local image publication, digest-pinned workloads, Cilium policy, and in-cluster health are proven. Stage 8 can add Log Analytics, Application Insights, Azure Monitor managed service for Prometheus, and Managed Grafana without changing the healthy application baseline.
