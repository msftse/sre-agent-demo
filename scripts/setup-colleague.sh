#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly CANONICAL_REPOSITORY="msftse/sre-agent-demo"
readonly UUID_PATTERN='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
readonly SUFFIX_PATTERN='^[a-z0-9]{4,8}$'
readonly LOCAL_REPOSITORY_PATTERN='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
readonly CHANNEL_PATTERN='^19:[^[:space:]]+@thread\.tacv2$'
# shellcheck source=scripts/lib/repository.sh
source "$ROOT_DIR/scripts/lib/repository.sh"

force=0
dry_run=0
allow_canonical=0
output_dir="$ROOT_DIR"
temp_output_dir_created=0

subscription_id=""
tenant_id=""
name_suffix=""
teams_tenant_id=""
teams_team_id=""
teams_channel_id=""
teams_user_object_id=""
owner_email=""
location="swedencentral"
github_environment="demo"

usage() {
  cat <<'USAGE'
Usage: ./scripts/setup-colleague.sh [options]

Options:
  --subscription-id <uuid>      Azure subscription ID (default: az account show)
  --tenant-id <uuid>            Azure tenant ID (default: az account show)
  --name-suffix <suffix>        4-8 lowercase alphanumeric suffix (default: derived from GitHub login)
  --teams-tenant-id <uuid>      Teams tenant ID (default: tenant ID)
  --teams-team-id <uuid>        Teams Team ID (required)
  --teams-channel-id <value>    Teams channel ID (required)
  --teams-user-object-id <uuid> Teams allowed user object ID (default: az signed-in user)
  --owner-email <email>         Owner tag value (default: az account user.name)
  --location <slug>             Azure location slug (default: swedencentral)
  --output-dir <path>           Output root directory (default: repository root)
  --allow-canonical             Permit msftse/sre-agent-demo for maintainer use
  --force                       Overwrite existing output files
  --dry-run                     Validate and render to temp dir (or --output-dir) without touching defaults
  -h, --help                    Show this message

Internal test-only environment overrides (dry-run only):
  DEMO_SETUP_REPOSITORY
  DEMO_SETUP_REPOSITORY_JSON
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command is missing: $1"
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

derive_suffix_from_login() {
  local login=$1
  local normalized
  local checksum
  local suffix

  normalized=$(tr '[:upper:]' '[:lower:]' <<<"$login" | tr -cd 'a-z0-9')
  if [[ -z "$normalized" ]]; then
    normalized="demo"
  fi

  suffix=${normalized:0:8}
  if (( ${#suffix} < 4 )); then
    checksum=$(cksum <<<"$login" | awk '{print $1}')
    suffix+="$checksum"
    suffix=${suffix:0:8}
  fi

  if (( ${#suffix} < 4 )); then
    suffix="demo1"
  fi

  printf '%s\n' "$suffix"
}

hcl_string() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

validate_uuid() {
  local label=$1
  local value=$2
  [[ "$value" =~ $UUID_PATTERN ]] || fail "$label must be a UUID"
}

validate_repository() {
  local repository=$1
  [[ "$repository" =~ $LOCAL_REPOSITORY_PATTERN ]] || fail "Repository must be in owner/repository format"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription-id)
      [[ $# -ge 2 ]] || fail "Missing value for --subscription-id"
      subscription_id=$(trim "$2")
      shift 2
      ;;
    --tenant-id)
      [[ $# -ge 2 ]] || fail "Missing value for --tenant-id"
      tenant_id=$(trim "$2")
      shift 2
      ;;
    --name-suffix)
      [[ $# -ge 2 ]] || fail "Missing value for --name-suffix"
      name_suffix=$(trim "$2")
      shift 2
      ;;
    --teams-tenant-id)
      [[ $# -ge 2 ]] || fail "Missing value for --teams-tenant-id"
      teams_tenant_id=$(trim "$2")
      shift 2
      ;;
    --teams-team-id)
      [[ $# -ge 2 ]] || fail "Missing value for --teams-team-id"
      teams_team_id=$(trim "$2")
      shift 2
      ;;
    --teams-channel-id)
      [[ $# -ge 2 ]] || fail "Missing value for --teams-channel-id"
      teams_channel_id=$(trim "$2")
      shift 2
      ;;
    --teams-user-object-id)
      [[ $# -ge 2 ]] || fail "Missing value for --teams-user-object-id"
      teams_user_object_id=$(trim "$2")
      shift 2
      ;;
    --owner-email)
      [[ $# -ge 2 ]] || fail "Missing value for --owner-email"
      owner_email=$(trim "$2")
      shift 2
      ;;
    --location)
      [[ $# -ge 2 ]] || fail "Missing value for --location"
      location=$(trim "$2")
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || fail "Missing value for --output-dir"
      output_dir=$(cd "$2" 2>/dev/null && pwd || true)
      if [[ -z "$output_dir" ]]; then
        mkdir -p "$2"
        output_dir=$(cd "$2" && pwd)
      fi
      shift 2
      ;;
    --allow-canonical)
      allow_canonical=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

require_command az
require_command gh
require_command jq
require_command git

account_json=$(az account show -o json)
if [[ -z "$subscription_id" ]]; then
  subscription_id=$(jq -r '.id // empty' <<<"$account_json")
fi
if [[ -z "$tenant_id" ]]; then
  tenant_id=$(jq -r '.tenantId // empty' <<<"$account_json")
fi
if [[ -z "$owner_email" ]]; then
  owner_email=$(jq -r '.user.name // empty' <<<"$account_json")
fi
if [[ -z "$teams_user_object_id" ]]; then
  teams_user_object_id=$(az ad signed-in-user show --query id -o tsv)
fi
if [[ -z "$teams_tenant_id" ]]; then
  teams_tenant_id="$tenant_id"
fi

validate_uuid "subscription-id" "$subscription_id"
validate_uuid "tenant-id" "$tenant_id"
validate_uuid "teams-tenant-id" "$teams_tenant_id"
validate_uuid "teams-team-id" "$teams_team_id"
validate_uuid "teams-user-object-id" "$teams_user_object_id"

[[ "$teams_channel_id" =~ $CHANNEL_PATTERN ]] || fail "teams-channel-id must match 19:<id>@thread.tacv2"
[[ "$location" =~ ^[a-z0-9-]+$ ]] || fail "location must be an Azure location slug"
[[ -n "$owner_email" ]] || fail "owner-email cannot be empty"
[[ "$github_environment" == "demo" ]] || fail "github-environment must be demo"

location_exists=$(az account list-locations --query "[?name=='$location'] | length(@)" -o tsv)
[[ "$location_exists" == "1" ]] || fail "Azure location is not available: $location"

repository_override=${DEMO_SETUP_REPOSITORY:-}
if [[ -n "$repository_override" ]]; then
  (( dry_run == 1 )) || fail "DEMO_SETUP_REPOSITORY is only allowed in --dry-run mode"
  repository="$repository_override"
else
  require_origin_remote_repository >/dev/null || fail "Git origin remote must be configured before repository resolution"
  repository=$(resolve_repository)
fi

validate_repository "$repository"

repository_json_override=${DEMO_SETUP_REPOSITORY_JSON:-}
if [[ -n "$repository_json_override" ]]; then
  (( dry_run == 1 )) || fail "DEMO_SETUP_REPOSITORY_JSON is only allowed in --dry-run mode"
  repository_json=$repository_json_override
else
  repository_json=$(gh api "repos/$repository")
fi

github_owner_id=$(jq -r '.owner.id // empty' <<<"$repository_json")
github_repository_id=$(jq -r '.id // empty' <<<"$repository_json")
repository_parent=$(jq -r '.parent.full_name // empty' <<<"$repository_json")
repository_is_fork=$(jq -r '.fork // false' <<<"$repository_json")

[[ "$github_owner_id" =~ ^[0-9]+$ ]] || fail "Unable to resolve numeric GitHub owner ID"
[[ "$github_repository_id" =~ ^[0-9]+$ ]] || fail "Unable to resolve numeric GitHub repository ID"

if [[ "$repository" == "$CANONICAL_REPOSITORY" ]]; then
  (( allow_canonical == 1 )) || fail "Canonical repository requires --allow-canonical"
else
  [[ "$repository_is_fork" == "true" ]] || fail "Repository must be a fork of $CANONICAL_REPOSITORY"
  [[ "$repository_parent" == "$CANONICAL_REPOSITORY" ]] || {
    fail "Repository fork parent must be $CANONICAL_REPOSITORY"
  }
fi

if [[ -n "$repository_json_override" ]] && jq -e '.viewerPermission? != null' >/dev/null <<<"$repository_json"; then
  viewer_permission=$(jq -r '.viewerPermission' <<<"$repository_json")
else
  viewer_permission=$(gh repo view "$repository" --json viewerPermission --jq '.viewerPermission')
fi
[[ "$viewer_permission" == "ADMIN" ]] || fail "GitHub ADMIN permission is required on $repository"

if [[ -z "$name_suffix" ]]; then
  login=$(gh api user --jq '.login')
  name_suffix=$(derive_suffix_from_login "$login")
fi

[[ "$name_suffix" =~ $SUFFIX_PATTERN ]] || {
  fail "name-suffix must be 4-8 lowercase alphanumeric characters"
}

if (( dry_run == 1 )) && [[ "$output_dir" == "$ROOT_DIR" ]]; then
  output_dir=$(mktemp -d "${TMPDIR:-/tmp}/sre-colleague-profile.XXXXXX")
  temp_output_dir_created=1
fi

profile_path="$output_dir/.demo-profile.env"
tfvars_dir="$output_dir/iac"
tfvars_path="$tfvars_dir/terraform.tfvars"
mkdir -p "$tfvars_dir"

if [[ -e "$profile_path" || -e "$tfvars_path" ]]; then
  (( force == 1 )) || fail "Refusing to overwrite existing files without --force"
fi

write_profile() {
  local path=$1
  {
    printf '# Generated by scripts/setup-colleague.sh\n'
    printf 'DEMO_SUBSCRIPTION_ID=%q\n' "$subscription_id"
    printf 'DEMO_TENANT_ID=%q\n' "$tenant_id"
    printf 'DEMO_LOCATION=%q\n' "$location"
    printf 'DEMO_GITHUB_REPOSITORY=%q\n' "$repository"
    printf 'DEMO_GITHUB_REPOSITORY_OWNER_ID=%q\n' "$github_owner_id"
    printf 'DEMO_GITHUB_REPOSITORY_ID=%q\n' "$github_repository_id"
    printf 'DEMO_GITHUB_ENVIRONMENT=%q\n' "$github_environment"
    printf 'DEMO_NAME_SUFFIX=%q\n' "$name_suffix"
    printf 'DEMO_TEAMS_TENANT_ID=%q\n' "$teams_tenant_id"
    printf 'DEMO_TEAMS_TEAM_ID=%q\n' "$teams_team_id"
    printf 'DEMO_TEAMS_CHANNEL_ID=%q\n' "$teams_channel_id"
    printf 'DEMO_TEAMS_ALLOWED_USER_OBJECT_ID=%q\n' "$teams_user_object_id"
    printf 'DEMO_OWNER_EMAIL=%q\n' "$owner_email"
  } >"$path"
}

write_tfvars() {
  local path=$1
  {
    printf 'subscription_id = %s\n' "$(hcl_string "$subscription_id")"
    printf 'tenant_id       = %s\n' "$(hcl_string "$tenant_id")"
    printf 'location        = %s\n' "$(hcl_string "$location")"
    printf 'environment     = %s\n' "$(hcl_string "demo")"
    printf 'project_name    = %s\n' "$(hcl_string "sre-agent-demo")"
    printf 'name_suffix     = %s\n' "$(hcl_string "$name_suffix")"
    printf '\n'
    printf 'acr_sku                = %s\n' '"Standard"'
    printf 'aks_node_count         = 2\n'
    printf 'aks_node_vm_size       = %s\n' '"Standard_D2ds_v5"'
    printf 'aks_sku_tier           = %s\n' '"Free"'
    printf 'aks_operator_object_id = null\n'
    printf '\n'
    printf 'github_repository          = %s\n' "$(hcl_string "$repository")"
    printf 'github_environment         = %s\n' "$(hcl_string "$github_environment")"
    printf 'github_repository_owner_id = %s\n' "$github_owner_id"
    printf 'github_repository_id       = %s\n' "$github_repository_id"
    printf '\n'
    printf 'enable_observability = true\n'
    printf 'enable_sre_agent     = true\n'
    printf 'enable_teams_bridge  = true\n'
    printf '\n'
    printf 'teams_tenant_id              = %s\n' "$(hcl_string "$teams_tenant_id")"
    printf 'teams_team_id                = %s\n' "$(hcl_string "$teams_team_id")"
    printf 'teams_channel_id             = %s\n' "$(hcl_string "$teams_channel_id")"
    printf 'teams_allowed_user_object_id = %s\n' "$(hcl_string "$teams_user_object_id")"
    printf '\n'
    printf 'tags = {\n'
    printf '  Owner = %s\n' "$(hcl_string "$owner_email")"
    printf '}\n'
  } >"$path"
}

cleanup_temp_output_dir() {
  if (( temp_output_dir_created == 1 )) && [[ -d "$output_dir" ]]; then
    rm -rf "$output_dir"
    printf 'Dry-run cleanup: removed temporary output directory created by this script.\n'
  fi
}

if (( dry_run == 1 )) && (( temp_output_dir_created == 1 )); then
  trap cleanup_temp_output_dir EXIT
fi

write_profile "$profile_path"
write_tfvars "$tfvars_path"
chmod 600 "$profile_path" "$tfvars_path"

if (( dry_run == 1 )); then
  printf 'PASS: dry-run rendered profile artifacts.\n'
else
  printf 'PASS: generated local profile artifacts.\n'
fi
printf 'Output directory:   %s\n' "$output_dir"
printf 'GitHub repository:  %s\n' "$repository"
printf 'Subscription ID:    %s\n' "$subscription_id"
printf 'Name suffix:        %s\n' "$name_suffix"
printf 'Teams tenant ID:    %s\n' "$teams_tenant_id"
