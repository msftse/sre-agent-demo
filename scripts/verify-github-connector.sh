#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly CONNECTOR_NAME="northstar-github"
# shellcheck source=scripts/lib/repository.sh
source "$ROOT_DIR/scripts/lib/repository.sh"
REPOSITORY=$(resolve_repository)
readonly REPOSITORY
readonly EXPECTED_TOOLS=(
  northstar-github_add_issue_comment
  northstar-github_create_branch
  northstar-github_create_pull_request
  northstar-github_get_file_contents
  northstar-github_pull_request_read
  northstar-github_push_files
  northstar-github_search_code
)
readonly FORBIDDEN_TOOLS=(
  northstar-github_create_pull_request_with_copilot
  northstar-github_merge_pull_request
  northstar-github_pull_request_review_write
  northstar-github_update_pull_request
  northstar-github_update_pull_request_branch
)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { printf '%s\n' 'GitHub CLI is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v shellcheck >/dev/null 2>&1 || { printf '%s\n' 'ShellCheck is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

bash -n "$ROOT_DIR/scripts/configure-sre-github-connector.sh"
shellcheck -x "$ROOT_DIR/scripts/configure-sre-github-connector.sh"

connector_file=$(mktemp "${TMPDIR:-/tmp}/sre-github-verify.XXXXXX")
branch_protection_file=$(mktemp "${TMPDIR:-/tmp}/github-protection.XXXXXX")
environment_file=$(mktemp "${TMPDIR:-/tmp}/github-environment.XXXXXX")
branch_policy_file=$(mktemp "${TMPDIR:-/tmp}/github-environment-branch.XXXXXX")
workflow_permissions_file=$(mktemp "${TMPDIR:-/tmp}/github-workflow-permissions.XXXXXX")
chmod 600 \
  "$connector_file" \
  "$branch_protection_file" \
  "$environment_file" \
  "$branch_policy_file" \
  "$workflow_permissions_file"

cleanup() {
  unset access_token
  rm -f \
    "$connector_file" \
    "$branch_protection_file" \
    "$environment_file" \
    "$branch_policy_file" \
    "$workflow_permissions_file"
}
trap cleanup EXIT

sre_endpoint=$(terraform -chdir="$IAC_DIR" output -json sre_agent | jq -er '.endpoint')
access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

curl --fail-with-body --silent --show-error \
  --output "$connector_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v2/extendedAgent/connectors/$CONNECTOR_NAME"

expected_tools_json=$(printf '%s\n' "${EXPECTED_TOOLS[@]}" | jq -R . | jq -s 'sort')
jq -e \
  --arg repository "$REPOSITORY" \
  --argjson tools "$expected_tools_json" \
  '
    .name == "northstar-github"
    and .properties.dataConnectorType == "Mcp"
    and (.properties.dataSource == null or .properties.dataSource == $repository)
    and (
      .properties.extendedProperties.endpoint == null
      or .properties.extendedProperties.endpoint == "https://api.githubcopilot.com/mcp/"
    )
    and .properties.extendedProperties.authType == "CustomHeaders"
    and ((.properties.extendedProperties.toolsVisibleToMetaAgent | sort) == $tools)
    and (
      .properties.extendedProperties.selectedTools == null
      or ((.properties.extendedProperties.selectedTools | sort) == $tools)
    )
    and (
      .properties.extendedProperties.Authorization == null
      or (.properties.extendedProperties.Authorization | startswith("Bearer "))
    )
  ' "$connector_file" >/dev/null

for forbidden_tool in "${FORBIDDEN_TOOLS[@]}"; do
  jq -e --arg forbidden_tool "$forbidden_tool" '
    all((.properties.extendedProperties.selectedTools // [])[]; . != $forbidden_tool)
    and all(.properties.extendedProperties.toolsVisibleToMetaAgent[]; . != $forbidden_tool)
  ' "$connector_file" >/dev/null
done

gh api "repos/$REPOSITORY/branches/main/protection" >"$branch_protection_file"
gh api "repos/$REPOSITORY/environments/demo" >"$environment_file"
gh api "repos/$REPOSITORY/environments/demo/deployment-branch-policies" >"$branch_policy_file"
gh api "repos/$REPOSITORY/actions/permissions/workflow" >"$workflow_permissions_file"

jq -e '
  .required_status_checks.strict == true
  and .required_status_checks.contexts == ["Validate source and chart"]
  and .required_pull_request_reviews == null
  and .required_conversation_resolution.enabled == true
  and .enforce_admins.enabled == true
  and .allow_force_pushes.enabled == false
  and .allow_deletions.enabled == false
' "$branch_protection_file" >/dev/null

jq -e '
  all(.protection_rules[]; .type != "required_reviewers")
' "$environment_file" >/dev/null

jq -e '
  .total_count == 1
  and .branch_policies[0].name == "main"
  and .branch_policies[0].type == "branch"
' "$branch_policy_file" >/dev/null

jq -e '
  .default_workflow_permissions == "read"
  and .can_approve_pull_request_reviews == false
' "$workflow_permissions_file" >/dev/null

printf '%s\n' 'PASS: GitHub connector exposes exactly seven approved tools.'
printf '%s\n' 'PASS: merge, review, and pull-request mutation tools are unavailable.'
printf '%s\n' 'PASS: main requires validation and user merge with no separate approving review.'
printf '%s\n' 'PASS: demo deployment has no reviewer gate and accepts only main.'
printf '%s\n' 'PASS: workflow tokens are read-only and cannot approve pull requests.'