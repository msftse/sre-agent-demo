# Stage 5: Hardened Containers and Helm

## Goal

Package the reviewed and instrumented application into small, non-root images and model its AKS deployment with secure, observable, configurable Helm resources. This stage creates no Azure resources.

## Images

### Backend

- Builder/runtime base: `python:3.12.13-slim-bookworm`.
- Runtime dependencies install from `https://packagefeedproxy.microsoft.io/pypi/simple`.
- The build stage creates a wheel-backed virtual environment; only that environment enters the runtime stage.
- Runtime UID/GID: `10001:10001`.
- Port: `8000`.
- Docker health check: `/health/live`.
- OCI labels carry title, source repository, version, and Git revision.

### Frontend

- Builder base: `node:24.13.1-alpine3.22`.
- Runtime base: `nginxinc/nginx-unprivileged:1.29.4-alpine3.23`.
- npm dependencies install from `https://packagefeedproxy.microsoft.io/npm/`.
- Runtime contains only the static Vite output and Nginx configuration.
- Runtime UID/GID: `101:101`.
- Port: `8080`.
- Docker health check: `/healthz`.
- Nginx provides SPA fallback, four browser security headers, and same-origin proxying for `/api`, `/health`, and `/metrics` to `http://backend:8000`.

The initial attempt used Nginx runtime environment substitution. Testing under a read-only root filesystem showed the unprivileged entrypoint could not create `/etc/nginx/conf.d/default.conf`. The final design bakes the stable Kubernetes Service name into the image, removes that runtime write, and avoids an init container.

## Restricted Runtime

Both images passed a real Docker smoke run with:

- `--read-only`.
- `--cap-drop ALL`.
- `--security-opt no-new-privileges:true`.
- A small `noexec,nosuid` temporary filesystem at `/tmp`.
- Non-root runtime users.

The smoke test verified catalogue, checkout, metrics, release metadata, SPA deep-link fallback, and security headers through the frontend's same-origin proxy. Attempts to write to either root filesystem failed as expected.

## Helm Resources

Default rendering creates:

- Restricted-labeled namespace.
- Tokenless ServiceAccount.
- Backend Deployment and stable `backend` Service.
- Frontend Deployment and Service.
- Two PodDisruptionBudgets.
- Backend and frontend NetworkPolicies.
- Azure Managed Prometheus ServiceMonitor.
- Helm connection test pod.

Optional rendering adds:

- Public ingress and optional TLS secret reference.
- Traffic-generator Deployment and its NetworkPolicy.

Workloads include startup, readiness, and liveness probes; rolling updates with zero unavailable replicas; revision-history limits; requests/limits; downward-API pod identity; release Git SHA/image annotations; and Restricted-compatible security contexts.

## Azure Managed Prometheus

The chart uses:

```yaml
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
```

The ServiceMonitor selects only the backend Service's named `metrics` port and includes Microsoft's required limits:

```yaml
labelLimit: 63
labelNameLengthLimit: 511
labelValueLengthLimit: 1023
```

No scrape credential is required, so Kubernetes 1.37 namespace-scoped secret access is not needed.

## Immutable Deployment

The chart accepts tags for local work but production deployment must provide both image digests:

First build and push from the local Docker daemon after the registry exists and Docker authentication has been established:

```bash
./scripts/publish-images.sh --registry <acr-name>.azurecr.io
```

The publishing script:

- Uses `docker build` locally, targeting `linux/amd64` for the AKS node pool.
- Tags both repositories with the current 12-character Git SHA.
- Uses `docker push` for publication.
- Extracts the registry-generated digest from each push.
- Prints exact Helm repository/digest values.
- Never invokes Azure CLI, ACR build/import, or remote ACR tasks.
- Never accepts or stores registry credentials; Docker must already be authenticated.

Then use the printed values:

```bash
helm upgrade --install northstar deploy/helm/sre-demo \
  --namespace northstar \
  --create-namespace \
  --set backend.image.repository=<acr>.azurecr.io/backend \
  --set backend.image.digest=sha256:<backend-digest> \
  --set frontend.image.repository=<acr>.azurecr.io/frontend \
  --set frontend.image.digest=sha256:<frontend-digest> \
  --set release.gitSha=<git-sha> \
  --set release.imageDigest=sha256:<backend-digest>
```

The values schema rejects malformed SHA-256 digest values.

For Stage 5 verification, the same workflow is exercised against a temporary local Docker Registry. The real ACR push cannot occur until Terraform creates the registry and its login server is available.

## Verification

Run:

```bash
./scripts/verify-containers.sh
```

The verifier:

1. Builds both images with the current Git SHA.
2. Asserts non-root users and OCI revision labels.
3. Runs both containers on an isolated network with Kubernetes-equivalent restrictions.
4. Proves same-origin application, telemetry, release, SPA, and security-header behavior.
5. Lints the Helm chart and renders default and all-conditional configurations.
6. Proves the values schema rejects an invalid digest.
7. Parses the manifests and asserts Restricted security, requests/limits, token hardening, NetworkPolicies, and ServiceMonitor limits.
8. Generates and validates SPDX JSON SBOMs.
9. Removes all containers, networks, ports, and temporary files.

Validated results:

```text
Backend image: user 10001:10001, approximately 62.6 MB, 134 SBOM packages
Frontend image: user 101:101, approximately 23.8 MB, 71 SBOM packages
Default chart: 12 resources, 2 Deployments, 2 NetworkPolicies
Full chart: 15 resources, 3 Deployments, 3 NetworkPolicies
Runtime smoke: passed
Helm lint/schema/render: passed
Restricted security assertions: passed
Cleanup: passed
```

Docker Scout was available but required interactive Docker authentication for CVE data. No credential was requested or bypassed. Authenticated image scanning remains a required Stage 9 GitHub Actions gate.

No reachable local Kubernetes cluster or local-cluster tool (`kind`, `minikube`, or `k3d`) is installed. A real Helm installation, API-server admission, Cilium NetworkPolicy enforcement, and `helm test` are explicitly deferred to Stage 7 on the newly provisioned AKS cluster.

## References

- [AKS pod security best practices](https://learn.microsoft.com/azure/aks/developer-best-practices-pod-security)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Azure Managed Prometheus ServiceMonitor](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-crd)

## Outcome

Stage 5 passed. The images and chart are ready for the Terraform foundation and subsequent AKS deployment stages.