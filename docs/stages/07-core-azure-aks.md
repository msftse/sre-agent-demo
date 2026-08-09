# Stage 7: Core Azure and AKS Platform

## Goal

Provision the approved core Azure platform with Terraform, publish the application images from the local Docker daemon, and prove the hardened Helm workload on AKS before adding observability.

## Provisioned Platform

Resource names are generated per deployment. Retrieve the reusable identifiers with:

```bash
terraform -chdir=iac output -json | jq '{
  resource_group: .resource_group_name.value,
  suffix: .resource_name_suffix.value,
  aks: .aks_name.value,
  aks_node_resource_group: .aks_node_resource_group.value,
  acr_login_server: .acr_login_server.value,
  ingress_public_ip: .ingress_public_ip_address.value
}'
```

The AKS system pool contains two `Standard_D2ds_v5` Azure Linux nodes. Query readiness and the current Kubernetes version from the recreated cluster. Host encryption, OIDC, workload identity, managed Entra authentication, Azure RBAC, Cilium, and the hardened settings defined in Stage 6 are enabled.

## Terraform Apply

The ignored configuration can provide a deterministic suffix for a specific run; otherwise Terraform persists a generated suffix. Shared provider registrations remain outside environment state and are validated as subscription prerequisites. AKS host encryption also requires the subscription feature:

```text
Microsoft.Compute/EncryptionAtHost = Registered
```

The initial AKS create stopped before cluster creation because this feature was not registered. After explicit approval, the feature was registered and the Microsoft.Compute provider refreshed. The replacement saved plan was reviewed by checksum and contained exactly four creates: AKS and its three dependent RBAC assignments.

Azure added `FirstPartyUsage=/Unprivileged` to the reserved public IP. Removing this platform-owned metadata would replace the IP, so the network module ignores `ip_tags` while retaining Terraform ownership of the address and all configured tags.

A second approved saved plan added one optional, cluster-scoped `Azure Kubernetes Service RBAC Cluster Admin` assignment for the configured human operator. Subscription `Owner` alone does not grant Kubernetes data-plane access, and local accounts remain disabled. Reusable environments default `aks_operator_object_id` to `null`; this ignored demo configuration opts in with the operator's immutable Entra object ID.

Historical Stage 7 Terraform validation snapshot:

```text
16 resources tracked
No changes. Your infrastructure matches the configuration.
0 resources destroyed
```

## Images

Both images were built for `linux/amd64` on the local Docker daemon and published with `docker push`. No ACR build, import, or task command was used. The Stage 7 baseline used the current Git SHA tag and immutable digests returned by ACR; each recreated deployment must capture its own values from `scripts/publish-images.sh`. AKS pulls through its kubelet identity and cluster-scoped `AcrPull` assignment.

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
Helm release: deployed; revision captured from the current cluster
Backend replicas: 2/2 ready
Frontend replicas: 2/2 ready
Helm smoke test: Succeeded
PodDisruptionBudgets: 2
NetworkPolicies: 2
Restricted namespace labels: passed
Terraform drift: none
SecurityControl=Ignore: live audit passed across both resource groups
```

The Helm test verifies backend `/health/ready` and frontend `/healthz` through the live ClusterIP services. A local port-forward also returned the Northstar storefront with HTTP 200, and `/api/release` reported the deployed Git SHA in environment `demo`.

To review the deployed application:

```bash
export KUBECONFIG="${TMPDIR}/sre-agent-demo-kubeconfig"
az aks get-credentials \
  --resource-group "$(terraform -chdir=iac output -raw resource_group_name)" \
  --name "$(terraform -chdir=iac output -raw aks_name)" \
  --file "$KUBECONFIG" \
  --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl port-forward --namespace northstar \
  service/northstar-sre-demo-frontend 8080:8080
```

Open `http://127.0.0.1:8080/`.

## Outcome

Stage 7 is complete. Core Azure infrastructure, AKS access, local image publication, digest-pinned workloads, Cilium policy, and in-cluster health are proven. Stage 8 can add Log Analytics, Application Insights, Azure Monitor managed service for Prometheus, and Managed Grafana without changing the healthy application baseline.
