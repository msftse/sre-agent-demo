#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly CONNECTOR_NAME="northstar-teams"
readonly EXPECTED_TOOLS=(
  get_incident_thread
  post_incident_update
  reply_incident_thread
)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

request_file=$(mktemp "${TMPDIR:-/tmp}/sre-connector-request.XXXXXX")
response_file=$(mktemp "${TMPDIR:-/tmp}/sre-connector-response.XXXXXX")
connector_file=$(mktemp "${TMPDIR:-/tmp}/sre-connector-current.XXXXXX")
mcp_init_file=$(mktemp "${TMPDIR:-/tmp}/sre-connector-mcp-init.XXXXXX")
mcp_tools_file=$(mktemp "${TMPDIR:-/tmp}/sre-connector-mcp-tools.XXXXXX")
chmod 600 "$request_file" "$response_file" "$connector_file" "$mcp_init_file" "$mcp_tools_file"

cleanup() {
  unset access_token mcp_key
  rm -f \
    "$request_file" \
    "$response_file" \
    "$connector_file" \
    "$mcp_init_file" \
    "$mcp_tools_file"
}
trap cleanup EXIT

sre_endpoint=$(terraform -chdir="$IAC_DIR" output -json sre_agent | jq -er '.endpoint')
teams_output=$(terraform -chdir="$IAC_DIR" output -json teams_bridge)
key_vault_name=$(jq -er '.key_vault_name' <<<"$teams_output")
mcp_endpoint=$(jq -er '.mcp_endpoint' <<<"$teams_output")
mcp_endpoint="${mcp_endpoint%/}/"

mcp_key=$(az keyvault secret show \
  --vault-name "$key_vault_name" \
  --name mcp-shared-key \
  --query value \
  --output tsv)
access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

curl --silent --show-error \
  --output "$mcp_init_file" \
  --request POST \
  --header "x-mcp-key: $mcp_key" \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"sre-connector-bootstrap","version":"1.0"}}}' \
  "$mcp_endpoint"

jq -e '.result.serverInfo.name == "northstar-teams"' "$mcp_init_file" >/dev/null

curl --silent --show-error \
  --output "$mcp_tools_file" \
  --request POST \
  --header "x-mcp-key: $mcp_key" \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  "$mcp_endpoint"

expected_tools_json=$(printf '%s\n' "${EXPECTED_TOOLS[@]}" | jq -R . | jq -s 'sort')
actual_tools_json=$(jq -c '[.result.tools[].name] | sort' "$mcp_tools_file")
[[ "$actual_tools_json" == "$(jq -c . <<<"$expected_tools_json")" ]] || {
  printf 'MCP tool set does not match the expected Teams notification boundary.\n' >&2
  exit 1
}

selected_tools_json=$(printf '%s\n' "${EXPECTED_TOOLS[@]}" \
  | jq -R --arg connector "$CONNECTOR_NAME" '"\($connector)_" + .' \
  | jq -s .)

jq -n \
  --arg name "$CONNECTOR_NAME" \
  --arg endpoint "$mcp_endpoint" \
  --arg key "$mcp_key" \
  --argjson tools "$selected_tools_json" \
  '{
    name: $name,
    type: "AgentConnector",
    properties: {
      dataConnectorType: "Mcp",
      dataSource: "placeholder",
      extendedProperties: {
        type: "http",
        endpoint: $endpoint,
        authType: "CustomHeaders",
        "x-mcp-key": $key,
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
  printf 'SRE Agent connector create/update failed with HTTP %s.\n' "$http_code" >&2
  exit 1
}

curl --silent --show-error \
  --output "$connector_file" \
  --header "Authorization: Bearer $access_token" \
  "$connector_url"

jq -e \
  --arg endpoint "$mcp_endpoint" \
  --argjson tools "$selected_tools_json" \
  '
    .name == "northstar-teams"
    and .properties.dataConnectorType == "Mcp"
    and .properties.extendedProperties.endpoint == $endpoint
    and .properties.extendedProperties.authType == "CustomHeaders"
    and ((.properties.extendedProperties.toolsVisibleToMetaAgent | sort) == ($tools | sort))
    and ((.properties.extendedProperties.selectedTools | sort) == ($tools | sort))
    and (.properties.extendedProperties["x-mcp-key"] | type == "string")
    and (.properties.extendedProperties["x-mcp-key"] | length > 0)
  ' "$connector_file" >/dev/null

printf 'Azure SRE Agent connector configured: %s\n' "$CONNECTOR_NAME"
printf 'Endpoint: %s\n' "$mcp_endpoint"
printf 'Tools: %s\n' "${EXPECTED_TOOLS[*]}"