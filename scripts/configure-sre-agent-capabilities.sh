#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR

"$ROOT_DIR/scripts/configure-sre-teams-connector.sh"
"$ROOT_DIR/scripts/configure-sre-github-connector.sh"
"$ROOT_DIR/scripts/configure-sre-checkout-skill.sh"
"$ROOT_DIR/scripts/verify-checkout-skill.sh"
"$ROOT_DIR/scripts/configure-sre-checkout-responder.sh"
"$ROOT_DIR/scripts/configure-sre-checkout-response-plan.sh"
"$ROOT_DIR/scripts/verify-checkout-response-plan.sh"

printf '%s\n' 'Azure SRE Agent connectors, checkout skill, responder, and response plan are configured.'