#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly CHART_DIR="$ROOT_DIR/deploy/helm/sre-demo"
readonly GIT_SHA=$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)
readonly VERSION="0.1.0"
readonly BACKEND_IMAGE="sre-demo-backend:stage5"
readonly FRONTEND_IMAGE="sre-demo-frontend:stage5"
readonly NETWORK="sre-demo-stage5"
readonly BACKEND_CONTAINER="sre-demo-backend-stage5"
readonly FRONTEND_CONTAINER="sre-demo-frontend-stage5"
readonly FRONTEND_URL="http://127.0.0.1:15173"
readonly BACKEND_PORT="18000"
readonly FRONTEND_PORT="15173"
readonly DEFAULT_RENDER=$(mktemp "${TMPDIR:-/tmp}/sre-demo-default.XXXXXX.yaml")
readonly FULL_RENDER=$(mktemp "${TMPDIR:-/tmp}/sre-demo-full.XXXXXX.yaml")
readonly BACKEND_SBOM=$(mktemp "${TMPDIR:-/tmp}/sre-demo-backend.XXXXXX.spdx.json")
readonly FRONTEND_SBOM=$(mktemp "${TMPDIR:-/tmp}/sre-demo-frontend.XXXXXX.spdx.json")

cleanup() {
  docker rm -f "$FRONTEND_CONTAINER" "$BACKEND_CONTAINER" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
  rm -f "$DEFAULT_RENDER" "$FULL_RENDER" "$BACKEND_SBOM" "$FRONTEND_SBOM"
}
trap cleanup EXIT

cleanup

docker build \
  --build-arg "GIT_SHA=$GIT_SHA" \
  --build-arg "BUILD_VERSION=$VERSION" \
  --tag "$BACKEND_IMAGE" \
  "$ROOT_DIR/src/backend" >/dev/null

docker build \
  --build-arg "GIT_SHA=$GIT_SHA" \
  --build-arg "BUILD_VERSION=$VERSION" \
  --tag "$FRONTEND_IMAGE" \
  "$ROOT_DIR/src/frontend" >/dev/null

[[ $(docker image inspect "$BACKEND_IMAGE" --format '{{.Config.User}}') == "10001:10001" ]]
[[ $(docker image inspect "$FRONTEND_IMAGE" --format '{{.Config.User}}') == "101:101" ]]
[[ $(docker image inspect "$BACKEND_IMAGE" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}') == "$GIT_SHA" ]]
[[ $(docker image inspect "$FRONTEND_IMAGE" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}') == "$GIT_SHA" ]]

docker network create "$NETWORK" >/dev/null

docker run -d \
  --name "$BACKEND_CONTAINER" \
  --network "$NETWORK" \
  --network-alias backend \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --env "SRE_DEMO_GIT_SHA=$GIT_SHA" \
  --env "SRE_DEMO_IMAGE_DIGEST=sha256:localstage5" \
  --env "SRE_DEMO_ENVIRONMENT=container" \
  --publish "127.0.0.1:$BACKEND_PORT:8000" \
  "$BACKEND_IMAGE" >/dev/null

docker run -d \
  --name "$FRONTEND_CONTAINER" \
  --network "$NETWORK" \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --publish "127.0.0.1:$FRONTEND_PORT:8080" \
  "$FRONTEND_IMAGE" >/dev/null

if ! curl --retry 30 --retry-all-errors --retry-delay 0 --fail --silent \
  "$FRONTEND_URL/health/ready" >/dev/null; then
  docker logs "$BACKEND_CONTAINER" >&2 || true
  docker logs "$FRONTEND_CONTAINER" >&2 || true
  exit 1
fi

[[ $(curl --fail --silent "$FRONTEND_URL/api/products" | jq 'length') == "4" ]]
[[ $(curl --fail --silent \
  --request POST "$FRONTEND_URL/api/checkout" \
  --header 'Content-Type: application/json' \
  --data '{"email":"container@example.com","items":[{"product_id":"field-pack-28","quantity":1}]}' \
  | jq -r '.status') == "confirmed" ]]
[[ $(curl --fail --silent "$FRONTEND_URL/api/release" | jq -r '.git_sha') == "$GIT_SHA" ]]
grep -q 'northstar_checkout_attempts_total{outcome="confirmed"} 1.0' \
  < <(curl --fail --silent "$FRONTEND_URL/metrics")
curl --fail --silent "$FRONTEND_URL/catalogue/deep-link" | grep -q 'Northstar Supply'
[[ $(curl --fail --silent --dump-header - --output /dev/null "$FRONTEND_URL/" \
  | grep -icE '^(x-content-type-options|x-frame-options|referrer-policy|permissions-policy):') == "4" ]]

if docker exec "$BACKEND_CONTAINER" sh -c 'touch /rootfs-write-test' >/dev/null 2>&1; then
  printf '%s\n' 'Backend root filesystem is writable.' >&2
  exit 1
fi
if docker exec "$FRONTEND_CONTAINER" sh -c 'touch /rootfs-write-test' >/dev/null 2>&1; then
  printf '%s\n' 'Frontend root filesystem is writable.' >&2
  exit 1
fi

helm lint "$CHART_DIR" --namespace northstar >/dev/null
helm template northstar "$CHART_DIR" --namespace northstar >"$DEFAULT_RENDER"
helm template northstar "$CHART_DIR" \
  --namespace northstar \
  --set backend.image.repository=demo.azurecr.io/backend \
  --set backend.image.digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --set frontend.image.repository=demo.azurecr.io/frontend \
  --set frontend.image.digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  --set release.gitSha=abcdef123456 \
  --set release.imageDigest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --set ingress.enabled=true \
  --set ingress.host=northstar.203.0.113.10.nip.io \
  --set trafficGenerator.enabled=true >"$FULL_RENDER"

if helm template invalid "$CHART_DIR" --set backend.image.digest=not-a-digest >/dev/null 2>&1; then
  printf '%s\n' 'Helm values schema accepted an invalid image digest.' >&2
  exit 1
fi

"$ROOT_DIR/src/backend/.venv/bin/python" - "$DEFAULT_RENDER" "$FULL_RENDER" <<'PY'
from pathlib import Path
import sys
import yaml

for path_value, expected_deployments, expected_policies in (
    (sys.argv[1], 2, 2),
    (sys.argv[2], 3, 3),
):
    path = Path(path_value)
    documents = [document for document in yaml.safe_load_all(path.read_text()) if document]
    deployments = [document for document in documents if document["kind"] == "Deployment"]
    policies = [document for document in documents if document["kind"] == "NetworkPolicy"]
    assert len(deployments) == expected_deployments
    assert len(policies) == expected_policies
    for deployment in deployments:
        pod = deployment["spec"]["template"]["spec"]
        assert pod["securityContext"]["runAsNonRoot"] is True
        assert pod["securityContext"]["seccompProfile"]["type"] == "RuntimeDefault"
        assert pod["automountServiceAccountToken"] is False
        for container in pod["containers"]:
            security = container["securityContext"]
            assert security["allowPrivilegeEscalation"] is False
            assert security["readOnlyRootFilesystem"] is True
            assert security["capabilities"]["drop"] == ["ALL"]
            assert container["resources"]["requests"]
            assert container["resources"]["limits"]
    monitor = next(document for document in documents if document["kind"] == "ServiceMonitor")
    assert monitor["apiVersion"] == "azmonitoring.coreos.com/v1"
    assert [
        monitor["spec"]["labelLimit"],
        monitor["spec"]["labelNameLengthLimit"],
        monitor["spec"]["labelValueLengthLimit"],
    ] == [63, 511, 1023]
PY

docker sbom "$BACKEND_IMAGE" --format spdx-json >"$BACKEND_SBOM"
docker sbom "$FRONTEND_IMAGE" --format spdx-json >"$FRONTEND_SBOM"
jq -e '.spdxVersion and (.packages | length > 0)' "$BACKEND_SBOM" >/dev/null
jq -e '.spdxVersion and (.packages | length > 0)' "$FRONTEND_SBOM" >/dev/null

printf 'PASS: hardened images and Helm chart are valid.\n'
printf 'Git SHA: %s\n' "$GIT_SHA"
printf 'Images: backend user 10001, frontend user 101, read-only root filesystems\n'
printf 'Runtime: same-origin catalogue, checkout, metrics, release, SPA, security headers\n'
printf 'Helm: default and full renders, Restricted security, NetworkPolicies, ServiceMonitor\n'
printf 'SBOM: backend packages=%s frontend packages=%s\n' \
  "$(jq '.packages | length' "$BACKEND_SBOM")" \
  "$(jq '.packages | length' "$FRONTEND_SBOM")"
