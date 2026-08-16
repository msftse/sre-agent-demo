#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly CONNECTOR_NAME="northstar-github"
readonly MCP_ENDPOINT="https://api.githubcopilot.com/mcp/"
# shellcheck source=scripts/lib/repository.sh
source "$ROOT_DIR/scripts/lib/repository.sh"
REPOSITORY=$(resolve_repository)
readonly REPOSITORY
readonly EXPECTED_TOOLS=(
  add_issue_comment
  create_branch
  create_pull_request
  get_file_contents
  pull_request_read
  push_files
  search_code
)
readonly FORBIDDEN_TOOLS=(
  merge_pull_request
  pull_request_review_write
)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { printf '%s\n' 'GitHub CLI is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

request_file=$(mktemp "${TMPDIR:-/tmp}/sre-github-request.XXXXXX")
response_file=$(mktemp "${TMPDIR:-/tmp}/sre-github-response.XXXXXX")
connector_file=$(mktemp "${TMPDIR:-/tmp}/sre-github-current.XXXXXX")
mcp_headers_file=$(mktemp "${TMPDIR:-/tmp}/sre-github-headers.XXXXXX")
mcp_init_file=$(mktemp "${TMPDIR:-/tmp}/sre-github-init.XXXXXX")
mcp_tools_file=$(mktemp "${TMPDIR:-/tmp}/sre-github-tools.XXXXXX")
mcp_init_json=$(mktemp "${TMPDIR:-/tmp}/sre-github-init-json.XXXXXX")
mcp_tools_json=$(mktemp "${TMPDIR:-/tmp}/sre-github-tools-json.XXXXXX")
chmod 600 \
  "$request_file" \
  "$response_file" \
  "$connector_file" \
  "$mcp_headers_file" \
  "$mcp_init_file" \
  "$mcp_tools_file" \
  "$mcp_init_json" \
  "$mcp_tools_json"

cleanup() {
  unset access_token github_token session_id
  rm -f \
    "$request_file" \
    "$response_file" \
    "$connector_file" \
    "$mcp_headers_file" \
    "$mcp_init_file" \
    "$mcp_tools_file" \
    "$mcp_init_json" \
    "$mcp_tools_json"
}
trap cleanup EXIT

extract_sse_response() {
  local request_id=$1
  local source_file=$2
  local destination_file=$3

  sed -n 's/^data: //p' "$source_file" \
    | jq -s --argjson request_id "$request_id" \
      'map(select(.id == $request_id))[0]' >"$destination_file"

  jq -e '. != null and .error == null' "$destination_file" >/dev/null
}

sre_endpoint=$(terraform -chdir="$IAC_DIR" output -json sre_agent | jq -er '.endpoint')
github_token=$(gh auth token)
access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

common_mcp_headers=(
  --header "Authorization: Bearer $github_token"
  --header 'Content-Type: application/json'
  --header 'Accept: application/json, text/event-stream'
)

curl --fail-with-body --silent --show-error --max-time 30 \
  --dump-header "$mcp_headers_file" \
  --output "$mcp_init_file" \
  --request POST \
  "${common_mcp_headers[@]}" \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"northstar-sre-connector","version":"1.0"}}}' \
  "$MCP_ENDPOINT"

extract_sse_response 1 "$mcp_init_file" "$mcp_init_json"
jq -e '.result.serverInfo.name == "github-mcp-server"' "$mcp_init_json" >/dev/null

session_id=$(awk 'BEGIN { IGNORECASE=1 } /^mcp-session-id:/ { gsub("\r", "", $2); print $2 }' "$mcp_headers_file")
session_headers=()
if [[ -n "$session_id" ]]; then
  session_headers+=(--header "mcp-session-id: $session_id")
fi

curl --fail-with-body --silent --show-error --max-time 30 \
  --output /dev/null \
  --request POST \
  "${common_mcp_headers[@]}" \
  "${session_headers[@]}" \
  --data '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  "$MCP_ENDPOINT"

curl --fail-with-body --silent --show-error --max-time 30 \
  --output "$mcp_tools_file" \
  --request POST \
  "${common_mcp_headers[@]}" \
  "${session_headers[@]}" \
  --data '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  "$MCP_ENDPOINT"

extract_sse_response 2 "$mcp_tools_file" "$mcp_tools_json"

expected_tools_json=$(printf '%s\n' "${EXPECTED_TOOLS[@]}" | jq -R . | jq -s 'sort')
actual_tools_json=$(jq -c '[.result.tools[].name] | sort' "$mcp_tools_json")
jq -e \
  --argjson expected "$expected_tools_json" \
  --argjson actual "$actual_tools_json" \
  '$expected - $actual | length == 0' \
  <<<null >/dev/null

for forbidden_tool in "${FORBIDDEN_TOOLS[@]}"; do
  jq -e --arg forbidden_tool "$forbidden_tool" \
    'all(.[]; . != $forbidden_tool)' \
    <<<"$expected_tools_json" >/dev/null
done

selected_tools_json=$(printf '%s\n' "${EXPECTED_TOOLS[@]}" \
  | jq -R --arg connector "$CONNECTOR_NAME" '"\($connector)_" + .' \
  | jq -s .)

jq -n \
  --arg name "$CONNECTOR_NAME" \
  --arg endpoint "$MCP_ENDPOINT" \
  --arg authorization "Bearer $github_token" \
  --arg repository "$REPOSITORY" \
  --argjson tools "$selected_tools_json" \
  '{
    name: $name,
    type: "AgentConnector",
    properties: {
      dataConnectorType: "Mcp",
      dataSource: $repository,
      extendedProperties: {
        type: "http",
        endpoint: $endpoint,
        authType: "CustomHeaders",
        Authorization: $authorization,
        toolsVisibleToMetaAgent: $tools,
        selectedTools: $tools
      },
      identity: "",
      keyVaultUri: null,
      endpoint: null,
      source: "Agent"
    }
  }' >"$request_file"

connector_url="${sre_endpoint%/}/api/v2/extendedAgent/connectors/$CONNECTOR_NAME"
http_code=$(curl --silent --show-error \
  --output "$response_file" \
  --write-out '%{http_code}' \
  --request PUT \
  --header "Authorization: Bearer $access_token" \
  --header 'Content-Type: application/json' \
  --data-binary "@$request_file" \
  "$connector_url")

[[ "$http_code" == "200" || "$http_code" == "201" ]] || {
  printf 'SRE Agent GitHub connector create/update failed with HTTP %s.\n' "$http_code" >&2
  exit 1
}

curl --fail-with-body --silent --show-error \
  --output "$connector_file" \
  --header "Authorization: Bearer $access_token" \
  "$connector_url"

jq -e \
  --arg endpoint "$MCP_ENDPOINT" \
  --arg repository "$REPOSITORY" \
  --argjson tools "$selected_tools_json" \
  '
    .name == "northstar-github"
    and .properties.dataConnectorType == "Mcp"
    and (.properties.dataSource == null or .properties.dataSource == $repository)
    and (.properties.extendedProperties.endpoint == null or .properties.extendedProperties.endpoint == $endpoint)
    and .properties.extendedProperties.authType == "CustomHeaders"
    and ((.properties.extendedProperties.toolsVisibleToMetaAgent | sort) == ($tools | sort))
    and (
      .properties.extendedProperties.selectedTools == null
      or ((.properties.extendedProperties.selectedTools | sort) == ($tools | sort))
    )
    and (
      .properties.extendedProperties.Authorization == null
      or (.properties.extendedProperties.Authorization | startswith("Bearer "))
    )
  ' "$connector_file" >/dev/null

printf 'Azure SRE Agent connector configured: %s\n' "$CONNECTOR_NAME"
printf 'Repository: %s\n' "$REPOSITORY"
printf 'Tools: %s\n' "${EXPECTED_TOOLS[*]}"