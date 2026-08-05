#!/usr/bin/env bash

set -euo pipefail

resource_groups=()

usage() {
  printf '%s\n' 'Usage: ./scripts/audit-tags.sh --resource-group <name> [--resource-group <name> ...]'
}

while (( $# > 0 )); do
  case "$1" in
    --resource-group)
      [[ $# -ge 2 ]] || { printf '%s\n' 'Missing value for --resource-group.' >&2; exit 2; }
      resource_groups+=("$2")
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

(( ${#resource_groups[@]} > 0 )) || { usage >&2; exit 2; }

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }

total_resources=0
for resource_group in "${resource_groups[@]}"; do
  resources=$(az resource list --resource-group "$resource_group" --output json)
  missing=$(jq -r '
    .[]
    | select(.tags.SecurityControl != "Ignore")
    | [.type, .name] | @tsv
  ' <<<"$resources")

  group_tag=$(az group show --name "$resource_group" --query 'tags.SecurityControl' -o tsv)
  if [[ "$group_tag" != "Ignore" ]]; then
    printf 'Resource group %s is missing SecurityControl=Ignore.\n' "$resource_group" >&2
    exit 1
  fi

  if [[ -n "$missing" ]]; then
    printf 'Resources missing SecurityControl=Ignore in %s:\n%s\n' \
      "$resource_group" "$missing" >&2
    exit 1
  fi

  resource_count=$(jq 'length' <<<"$resources")
  total_resources=$((total_resources + resource_count))
  printf 'PASS: %s and %s resources include SecurityControl=Ignore.\n' \
    "$resource_group" "$resource_count"
done

printf 'PASS: audited %s resource groups and %s resources.\n' \
  "${#resource_groups[@]}" "$total_resources"
