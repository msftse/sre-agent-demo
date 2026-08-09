#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly APP_DIR="$ROOT_DIR/src/teams-bridge"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v func >/dev/null 2>&1 || { printf '%s\n' 'Azure Functions Core Tools v4 is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

function_app_name=$(terraform -chdir="$IAC_DIR" output -json teams_bridge | jq -r '.function_app_name')
key_vault_name=$(terraform -chdir="$IAC_DIR" output -json teams_bridge | jq -r '.key_vault_name')
messaging_endpoint=$(terraform -chdir="$IAC_DIR" output -json teams_bridge | jq -r '.messaging_endpoint')
bot_client_id=$(terraform -chdir="$IAC_DIR" output -json teams_bridge | jq -r '.bot_client_id')

for secret_name in bot-client-secret mcp-shared-key; do
  az keyvault secret show \
    --vault-name "$key_vault_name" \
    --name "$secret_name" \
    --query id \
    --output tsv >/dev/null || {
      printf 'Required Key Vault secret is missing: %s\n' "$secret_name" >&2
      exit 1
    }
done

(
  cd "$APP_DIR"
  func azure functionapp publish "$function_app_name" --python --build remote
)

function_hostname=${messaging_endpoint#https://}
function_hostname=${function_hostname%/api/messages}
"$ROOT_DIR/scripts/package-teams-app.sh" \
  --bot-client-id "$bot_client_id" \
  --function-hostname "$function_hostname"

curl --fail-with-body --silent --show-error "https://$function_hostname/api/health" | jq -e '.status == "ok"' >/dev/null
"$ROOT_DIR/scripts/configure-sre-agent-capabilities.sh"
printf 'Teams bridge deployed and healthy: https://%s/api/health\n' "$function_hostname"