#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly VERSION="${BUILD_VERSION:-0.1.0}"
readonly GIT_SHA="${GIT_SHA:-$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)}"
readonly TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"

registry=""
repository_prefix="northstar"

usage() {
  cat <<'EOF'
Usage: ./scripts/publish-images.sh --registry <login-server> [--repository-prefix <prefix>]

Builds both images with local Docker, tags them with the current Git SHA, pushes
them with docker push, and prints immutable digests for the Helm deployment.

Examples:
  ./scripts/publish-images.sh --registry localhost:15000
  ./scripts/publish-images.sh --registry myregistry.azurecr.io

Environment overrides:
  BUILD_VERSION    Image/application version (default: 0.1.0)
  GIT_SHA          Immutable image tag and OCI revision (default: current short SHA)
  TARGET_PLATFORM  Target image platform (default: linux/amd64 for AKS)

The registry must already be reachable. For a private registry, Docker must
already have credentials (for example, from an approved `docker login` flow).
This script never accepts credentials and never invokes Azure CLI or az acr.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --registry)
      [[ $# -ge 2 ]] || { printf '%s\n' 'Missing value for --registry.' >&2; exit 2; }
      registry=${2%/}
      shift 2
      ;;
    --repository-prefix)
      [[ $# -ge 2 ]] || { printf '%s\n' 'Missing value for --repository-prefix.' >&2; exit 2; }
      repository_prefix=${2#/}
      repository_prefix=${repository_prefix%/}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$registry" ]] || { printf '%s\n' '--registry is required.' >&2; usage >&2; exit 2; }
[[ "$registry" != *"://"* ]] || { printf '%s\n' 'Use a registry login server without a URL scheme.' >&2; exit 2; }
[[ "$repository_prefix" =~ ^[a-z0-9]+([._/-][a-z0-9]+)*$ ]] || {
  printf '%s\n' 'Repository prefix must contain lowercase registry path characters.' >&2
  exit 2
}
[[ "$GIT_SHA" =~ ^[0-9a-f]{7,64}$ ]] || {
  printf '%s\n' 'GIT_SHA must be a 7-64 character lowercase hexadecimal revision.' >&2
  exit 2
}

command -v docker >/dev/null 2>&1 || { printf '%s\n' 'Docker is required.' >&2; exit 1; }
docker info >/dev/null 2>&1 || { printf '%s\n' 'Docker daemon is unavailable.' >&2; exit 1; }

readonly BACKEND_REPOSITORY="$registry/$repository_prefix/backend"
readonly FRONTEND_REPOSITORY="$registry/$repository_prefix/frontend"
readonly BACKEND_IMAGE="$BACKEND_REPOSITORY:$GIT_SHA"
readonly FRONTEND_IMAGE="$FRONTEND_REPOSITORY:$GIT_SHA"

printf 'Building %s for %s...\n' "$BACKEND_IMAGE" "$TARGET_PLATFORM"
docker build \
  --platform "$TARGET_PLATFORM" \
  --build-arg "GIT_SHA=$GIT_SHA" \
  --build-arg "BUILD_VERSION=$VERSION" \
  --tag "$BACKEND_IMAGE" \
  "$ROOT_DIR/src/backend"

printf 'Building %s for %s...\n' "$FRONTEND_IMAGE" "$TARGET_PLATFORM"
docker build \
  --platform "$TARGET_PLATFORM" \
  --build-arg "GIT_SHA=$GIT_SHA" \
  --build-arg "BUILD_VERSION=$VERSION" \
  --tag "$FRONTEND_IMAGE" \
  "$ROOT_DIR/src/frontend"

for image in "$BACKEND_IMAGE" "$FRONTEND_IMAGE"; do
  revision=$(docker image inspect "$image" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}')
  [[ "$revision" == "$GIT_SHA" ]] || {
    printf 'Image %s has unexpected OCI revision %s.\n' "$image" "$revision" >&2
    exit 1
  }
done

push_and_get_digest() {
  local image=$1
  local output
  local digest

  printf 'Pushing %s...\n' "$image" >&2
  if ! output=$(docker push "$image" 2>&1); then
    printf '%s\n' "$output" >&2
    printf 'Push failed. Verify registry reachability and Docker authentication for %s.\n' \
      "$registry" >&2
    return 1
  fi
  printf '%s\n' "$output" >&2
  digest=$(sed -nE 's/^.*digest: (sha256:[0-9a-f]{64}).*$/\1/p' <<<"$output" | tail -1)
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    printf 'Could not extract pushed digest for %s.\n' "$image" >&2
    return 1
  }
  printf '%s\n' "$digest"
}

backend_digest=$(push_and_get_digest "$BACKEND_IMAGE")
frontend_digest=$(push_and_get_digest "$FRONTEND_IMAGE")

cat <<EOF

PASS: images built locally and pushed with Docker.

backend_repository=$BACKEND_REPOSITORY
backend_tag=$GIT_SHA
backend_digest=$backend_digest
frontend_repository=$FRONTEND_REPOSITORY
frontend_tag=$GIT_SHA
frontend_digest=$frontend_digest

Helm values:
  --set backend.image.repository=$BACKEND_REPOSITORY
  --set backend.image.digest=$backend_digest
  --set frontend.image.repository=$FRONTEND_REPOSITORY
  --set frontend.image.digest=$frontend_digest
  --set release.gitSha=$GIT_SHA
  --set release.imageDigest=$backend_digest
EOF
