#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly SKILL_FILE="$ROOT_DIR/sre-agent-skills/northstar-checkout-remediation.md"
readonly SKILL_NAME="northstar-checkout-remediation"
readonly EXPECTED_TOOLS=(
  RunAzCliReadCommands
  northstar-github_search_code
  northstar-github_get_file_contents
  northstar-github_pull_request_read
  northstar-github_create_branch
  northstar-github_push_files
  northstar-github_create_pull_request
  northstar-github_add_issue_comment
  northstar-teams_post_incident_update
  northstar-teams_reply_incident_thread
  northstar-teams_get_incident_thread
)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v shellcheck >/dev/null 2>&1 || { printf '%s\n' 'ShellCheck is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

bash -n "$ROOT_DIR/scripts/configure-sre-checkout-skill.sh"
shellcheck "$ROOT_DIR/scripts/configure-sre-checkout-skill.sh"

[[ $(sed -n '1p' "$SKILL_FILE") == '---' ]]
[[ $(grep -c '^---$' "$SKILL_FILE") -eq 2 ]]
grep -Fx "name: $SKILL_NAME" "$SKILL_FILE" >/dev/null

if grep -Eq '(ij[0-9]{4}|/subscriptions/[0-9a-f-]{36}|rg-sre-agent-demo|aks-sre-agent-demo|sre-sre-agent-demo)' "$SKILL_FILE"; then
  printf '%s\n' 'Skill source contains an environment-specific Azure identifier.' >&2
  exit 1
fi

# shellcheck disable=SC2016 # Backticks are literal Markdown in the skill contract.
for discovery_clause in \
  'Never assume an Azure subscription, resource group, AKS cluster' \
  'Run Azure CLI reads serially' \
  'Keep exactly one `RunAzCliReadCommands` call in flight' \
  'Prefer core `az resource`, `az rest`, and `az aks show` commands' \
  'Resolve the monitored AKS cluster and resource group from those resource IDs' \
  'Resolve linked Log Analytics, Azure Monitor workspace, and Application Insights resource IDs'; do
  grep -F "$discovery_clause" "$SKILL_FILE" >/dev/null
done

for tool in "${EXPECTED_TOOLS[@]}"; do
  grep -Fx "  - $tool" "$SKILL_FILE" >/dev/null
done

# shellcheck disable=SC2016 # Backticks are literal Markdown in the skill contract.
for clause in \
  'Never approve, merge, enable auto-merge, dispatch a workflow, deploy' \
  'Add a regression test for two `field-pack-28` items with `FIELD20`' \
  'total `23680`' \
  '<!-- sre-thread-id: <current-sre-thread-id> -->' \
  'After a successful delivery-workflow callback' \
  'Awaiting human PR review; no merge or deployment performed.'; do
  grep -F "$clause" "$SKILL_FILE" >/dev/null
done

skill_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-skill.XXXXXX")
chmod 600 "$skill_file"

cleanup() {
  unset access_token
  rm -f "$skill_file"
}
trap cleanup EXIT

sre_endpoint=$(terraform -chdir="$IAC_DIR" output -json sre_agent | jq -er '.endpoint')
access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

curl --fail-with-body --silent --show-error \
  --output "$skill_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v2/extendedAgent/skills/$SKILL_NAME"

jq -e \
  --arg name "$SKILL_NAME" \
  --argjson tools "$(printf '%s\n' "${EXPECTED_TOOLS[@]}" | jq -R . | jq -s 'sort')" \
  '
    .name == $name
    and .type == "Skill"
    and ((.properties.tools | sort) == $tools)
    and (.properties.description | type == "string" and length > 0)
  ' "$skill_file" >/dev/null

live_content=$(jq -er '.properties.skillContent' "$skill_file")
source_content=$(<"$SKILL_FILE")
[[ "$live_content" == "$source_content" ]]
unset live_content source_content

printf '%s\n' 'PASS: skill source front matter and eleven assigned tools validated.'
printf '%s\n' 'PASS: exact FIELD20 repair and regression-test contract validated.'
printf '%s\n' 'PASS: merge and deployment stop clauses validated.'
printf '%s\n' 'PASS: live Azure SRE Agent skill matches the repository source.'