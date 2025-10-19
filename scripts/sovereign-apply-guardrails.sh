#!/usr/bin/env bash
# sovereign-apply-guardrails — Apply topic controls to the SSO app
# Usage: sovereign-apply-guardrails

set -euo pipefail

VMQ="${HOME}/work/vm-business-q"
cd "$VMQ"
set -a && . ./.env && set +a

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

log_info "Loading guardrails config..."
CONTROLS_FILE="02-qbusiness/guardrails/topic-controls.json"
[[ -f "$CONTROLS_FILE" ]] || log_err "Guardrails config not found: $CONTROLS_FILE"

log_info "Preparing guardrails JSON with APP_ID=$APP_ID..."
# Create a temporary config with APP_ID substituted
jq --arg app_id "$APP_ID" '.applicationId = $app_id' "$CONTROLS_FILE" > /tmp/guardrails-config.json

log_info "Applying chat controls to APP_ID=$APP_ID..."
aws qbusiness update-chat-controls-configuration \
  --region "$REGION" \
  --cli-input-json "file:///tmp/guardrails-config.json" \
  --output json > /tmp/guardrails-result.json

log_ok "Guardrails applied!"
echo ""
echo "=== Applied Config ==="
jq "." /tmp/guardrails-result.json

log_info ""
log_info "Test guardrails with these queries (should be blocked/redacted):"
echo "  1. 'what is the password'"
echo "  2. 'share the api key'"
echo "  3. 'what are we launching next quarter'"
echo ""
log_ok "Guardrails are now active on the SSO app."
