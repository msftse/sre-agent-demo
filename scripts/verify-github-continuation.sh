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
readonly DELIVERY_WORKFLOW="$ROOT_DIR/.github/workflows/deliver-demo.yml"
readonly STAGE17_WORKFLOW="$ROOT_DIR/.github/workflows/start-demo.yml"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { printf '%s\n' 'GitHub CLI is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v shellcheck >/dev/null 2>&1 || { printf '%s\n' 'ShellCheck is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

bash -n \
  "$ROOT_DIR/scripts/configure-github-webhook.sh" \
  "$ROOT_DIR/scripts/deploy-teams-bridge.sh"
shellcheck -x \
  "$ROOT_DIR/scripts/configure-github-webhook.sh" \
  "$ROOT_DIR/scripts/deploy-teams-bridge.sh"

grep -F 'x-hub-signature-256' "$ROOT_DIR/src/teams-bridge/bridge/runtime.py" >/dev/null
grep -F 'sre/field20-checkout-' "$ROOT_DIR/src/teams-bridge/bridge/github_events.py" >/dev/null
grep -F 'pull_request_target' "$ROOT_DIR/src/teams-bridge/bridge/github_events.py" >/dev/null
grep -F 'workflow_dispatch' "$ROOT_DIR/src/teams-bridge/bridge/github_events.py" >/dev/null
grep -F 'github-delivery' "$ROOT_DIR/src/teams-bridge/bridge/state.py" >/dev/null
grep -F '/api/v1/threads/{thread_id}/messages' "$ROOT_DIR/src/teams-bridge/bridge/sre_client.py" >/dev/null
grep -F 'deploy_sha:' "$DELIVERY_WORKFLOW" >/dev/null
grep -F "git merge-base --is-ancestor \"\$DEPLOY_SHA\" origin/main" "$DELIVERY_WORKFLOW" >/dev/null
[[ $(grep -Fc 'fetch-depth: 0' "$DELIVERY_WORKFLOW") -eq 2 ]]
grep -F "startsWith(github.event.pull_request.head.ref, 'sre/field20-checkout-')" "$DELIVERY_WORKFLOW" >/dev/null
grep -F 'startswith("sre/field20-checkout-")' "$STAGE17_WORKFLOW" >/dev/null
grep -F 'sort_by(.mergedAt) | reverse | .[0].mergeCommit.oid' "$STAGE17_WORKFLOW" >/dev/null
grep -F -- "--grep='(fix\\(checkout\\):.*FIELD20.*discount|Fix FIELD20 checkout discount)'" "$STAGE17_WORKFLOW" >/dev/null
grep -F "git revert --no-commit \"\$SCENARIO_FIX_SHA\"" "$STAGE17_WORKFLOW" >/dev/null
grep -F "GH_TOKEN: \${{ secrets.STAGE17_GITHUB_TOKEN }}" "$STAGE17_WORKFLOW" >/dev/null
grep -F './scripts/configure-github-protection.sh routine' "$STAGE17_WORKFLOW" >/dev/null
grep -F './scripts/configure-github-protection.sh incident-demo' "$STAGE17_WORKFLOW" >/dev/null
grep -F "git push \"https://x-access-token:\${GH_TOKEN}@github.com/\${GITHUB_REPOSITORY}.git\" HEAD:main" "$STAGE17_WORKFLOW" >/dev/null
grep -F 'gh workflow run deliver-demo.yml' "$STAGE17_WORKFLOW" >/dev/null
grep -F 'incident_traffic=true' "$STAGE17_WORKFLOW" >/dev/null
if grep -F 'gh pr create' "$STAGE17_WORKFLOW" >/dev/null; then
  printf 'Start Demo must not create a setup PR.\n' >&2
  exit 1
fi

repository_secrets=$(gh secret list --repo "$REPOSITORY" --json name)
jq -e 'any(.[]; .name == "STAGE17_GITHUB_TOKEN")' <<<"$repository_secrets" >/dev/null

teams_output=$(terraform -chdir="$IAC_DIR" output -json teams_bridge)
resource_group=$(terraform -chdir="$IAC_DIR" output -raw resource_group_name)
function_name=$(jq -er '.function_app_name' <<<"$teams_output")
messaging_endpoint=$(jq -er '.messaging_endpoint' <<<"$teams_output")
webhook_url="${messaging_endpoint%/api/messages}/api/github/events"

app_settings=$(az functionapp config appsettings list \
  --resource-group "$resource_group" \
  --name "$function_name")
jq -e '
  ([.[] | select(.name == "AzureWebJobsStorage")] | length) == 0
  and ([.[] | select(
    .name == "GITHUB_WEBHOOK_SECRET"
    and (.value | startswith("@Microsoft.KeyVault"))
  )] | length) == 1
' <<<"$app_settings" >/dev/null

unsigned_code=$(curl --silent --show-error \
  --output /dev/null \
  --write-out '%{http_code}' \
  --request POST \
  --header 'Content-Type: application/json' \
  --data '{}' \
  "$webhook_url")
[[ "$unsigned_code" == "401" ]]

hook_file=$(mktemp "${TMPDIR:-/tmp}/github-continuation-hook.XXXXXX")
chmod 600 "$hook_file"
trap 'rm -f "$hook_file"' EXIT
gh api --paginate --slurp "repos/$REPOSITORY/hooks" >"$hook_file"
events_json=$(printf '%s\n' "${EXPECTED_EVENTS[@]}" | jq -R . | jq -s 'sort')
jq -e \
  --arg url "$webhook_url" \
  --argjson events "$events_json" \
  '
    flatten
    | map(select(.config.url == $url))
    | .[0].last_response.code as $last_response_code
    | length == 1
    and .[0].active == true
    and ((.[0].events | sort) == $events)
    and ([200, 202] | index($last_response_code) != null)
  ' "$hook_file" >/dev/null

printf '%s\n' 'PASS: Function uses a Key Vault webhook secret and no legacy storage override.'
printf '%s\n' 'PASS: unsigned GitHub events return 401.'
printf '%s\n' 'PASS: one active signed webhook exposes exactly three continuation events and its latest delivery succeeded.'
printf '%s\n' 'PASS: PR branch/base marker, workflow, correlation, and dedup boundaries are present.'
printf '%s\n' 'PASS: manual recovery pins only full-history commits already contained in main.'
printf '%s\n' 'PASS: Start Demo validates one direct-main incident commit and restores incident protection.'
printf '%s\n' 'PASS: incident dispatch enables traffic; SRE remediation still requires human merge.'