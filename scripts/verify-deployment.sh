#!/usr/bin/env bash

set -euo pipefail

release=""
namespace=""
git_sha=""
backend_repository=""
backend_digest=""
frontend_repository=""
frontend_digest=""
telemetry_client_id=""

usage() {
  cat <<'EOF'
Usage: ./scripts/verify-deployment.sh \
  --release <name> \
  --namespace <name> \
  --git-sha <sha> \
  --backend-repository <repository> \
  --backend-digest <sha256:digest> \
  --frontend-repository <repository> \
  --frontend-digest <sha256:digest> \
  --telemetry-client-id <client-id>
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --release) release=${2:-}; shift 2 ;;
    --namespace) namespace=${2:-}; shift 2 ;;
    --git-sha) git_sha=${2:-}; shift 2 ;;
    --backend-repository) backend_repository=${2:-}; shift 2 ;;
    --backend-digest) backend_digest=${2:-}; shift 2 ;;
    --frontend-repository) frontend_repository=${2:-}; shift 2 ;;
    --frontend-digest) frontend_digest=${2:-}; shift 2 ;;
    --telemetry-client-id) telemetry_client_id=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

for value_name in \
  release namespace git_sha backend_repository backend_digest \
  frontend_repository frontend_digest telemetry_client_id; do
  [[ -n "${!value_name}" ]] || {
    printf 'Required value %s is empty.\n' "$value_name" >&2
    exit 2
  }
done

[[ "$git_sha" =~ ^[0-9a-f]{7,64}$ ]] || {
  printf 'git-sha must be 7-64 lowercase hexadecimal characters.\n' >&2
  exit 2
}
[[ "$backend_digest" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$frontend_digest" =~ ^sha256:[0-9a-f]{64}$ ]]

command -v helm >/dev/null 2>&1 || { printf '%s\n' 'Helm is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { printf '%s\n' 'kubectl is required.' >&2; exit 1; }

helm_status=$(helm status "$release" --namespace "$namespace" --output json)
[[ $(jq -r '.info.status' <<<"$helm_status") == "deployed" ]]

deployments=$(kubectl get deployments --namespace "$namespace" --output json)
jq -e \
  --arg git_sha "$git_sha" \
  --arg backend_image "$backend_repository@$backend_digest" \
  --arg frontend_image "$frontend_repository@$frontend_digest" '
    (.items | length) == 2
    and all(.items[];
      .status.readyReplicas == .spec.replicas
      and .spec.replicas == 2
      and .spec.template.metadata.labels["sre-demo/git-sha"] == $git_sha
    )
    and ([.items[].spec.template.spec.containers[0].image] | index($backend_image) != null)
    and ([.items[].spec.template.spec.containers[0].image] | index($frontend_image) != null)
  ' <<<"$deployments" >/dev/null

service_account=$(kubectl get serviceaccount \
  "${release}-sre-demo-workload" \
  --namespace "$namespace" \
  --output json)
jq -e \
  --arg telemetry_client_id "$telemetry_client_id" '
    .metadata.annotations["azure.workload.identity/client-id"] == $telemetry_client_id
    and .automountServiceAccountToken == false
  ' <<<"$service_account" >/dev/null

kubectl get servicemonitor \
  "${release}-sre-demo-backend" \
  --namespace "$namespace" \
  --output json \
  | jq -e '
      .apiVersion == "azmonitoring.coreos.com/v1"
      and .spec.endpoints[0].path == "/metrics"
      and .spec.endpoints[0].port == "metrics"
    ' >/dev/null

helm test "$release" --namespace "$namespace" --logs --timeout 5m

printf 'PASS: %s/%s is deployed at %s with verified digests, telemetry identity, and smoke tests.\n' \
  "$namespace" "$release" "$git_sha"