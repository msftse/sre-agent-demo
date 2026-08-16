#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
# shellcheck source=scripts/lib/repository.sh
source "$ROOT_DIR/scripts/lib/repository.sh"
REPOSITORY=$(resolve_repository)
readonly REPOSITORY
readonly EXPECTED_EVENTS=(deployment_status pull_request workflow_run)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { printf '%s\n' 'GitHub CLI is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

request_file=$(mktemp "${TMPDIR:-/tmp}/github-hook-request.XXXXXX")
response_file=$(mktemp "${TMPDIR:-/tmp}/github-hook-response.XXXXXX")
hooks_file=$(mktemp "${TMPDIR:-/tmp}/github-hooks.XXXXXX")
current_file=$(mktemp "${TMPDIR:-/tmp}/github-hook-current.XXXXXX")
chmod 600 "$request_file" "$response_file" "$hooks_file" "$current_file"

cleanup() {
  unset webhook_secret
  rm -f "$request_file" "$response_file" "$hooks_file" "$current_file"
}
trap cleanup EXIT

teams_output=$(terraform -chdir="$IAC_DIR" output -json teams_bridge)
key_vault_name=$(jq -er '.key_vault_name' <<<"$teams_output")
messaging_endpoint=$(jq -er '.messaging_endpoint' <<<"$teams_output")
webhook_url="${messaging_endpoint%/api/messages}/api/github/events"
webhook_secret=$(az keyvault secret show \
  --vault-name "$key_vault_name" \
  --name github-webhook-secret \
  --query value \
  --output tsv)

events_json=$(printf '%s\n' "${EXPECTED_EVENTS[@]}" | jq -R . | jq -s .)
jq -n \
  --arg url "$webhook_url" \
  --arg secret "$webhook_secret" \
  --argjson events "$events_json" \
  '{
    name: "web",
    active: true,
    events: $events,
    config: {
      url: $url,
      content_type: "json",
      insecure_ssl: "0",
      secret: $secret
    }
  }' >"$request_file"

gh api --paginate --slurp "repos/$REPOSITORY/hooks" >"$hooks_file"
hook_id=$(jq -r --arg url "$webhook_url" '
  flatten | map(select(.config.url == $url)) | first | .id // empty
' "$hooks_file")

if [[ -n "$hook_id" ]]; then
  gh api --method PATCH "repos/$REPOSITORY/hooks/$hook_id" \
    --input "$request_file" >"$response_file"
else
  gh api --method POST "repos/$REPOSITORY/hooks" \
    --input "$request_file" >"$response_file"
  hook_id=$(jq -er '.id' "$response_file")
fi

gh api "repos/$REPOSITORY/hooks/$hook_id" >"$current_file"
jq -e \
  --arg url "$webhook_url" \
  --argjson events "$events_json" \
  '
    .active == true
    and .config.url == $url
    and .config.content_type == "json"
    and ((.events | sort) == ($events | sort))
  ' "$current_file" >/dev/null

printf 'GitHub continuation webhook configured: %s\n' "$webhook_url"
printf 'Events: %s\n' "${EXPECTED_EVENTS[*]}"