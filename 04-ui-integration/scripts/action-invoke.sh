#!/usr/bin/env bash
#
# VaultMesh Q Business - CLI Action Invocation Test
#
# Usage:
#   ./action-invoke.sh <action-id> <user-email> <user-group> <params-json>
#
# Examples:
#   ./action-invoke.sh summarize-docs alice@vaultmesh.io VaultMesh-Engineering \
#     '{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"]}'
#
#   ./action-invoke.sh validate-schema bob@vaultmesh.io VaultMesh-Engineering \
#     '{"schemaUri":"s3://bucket/schema.json","profile":"both"}'
#

set -euo pipefail

# Configuration
API_BASE="${API_BASE:-http://localhost:3000}"
ACTION="${1:-}"
USER="${2:-anon@vaultmesh.io}"
GROUP="${3:-VaultMesh-Engineering}"
PARAMS="${4:-{}}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [[ -z "$ACTION" ]]; then
  echo -e "${RED}Error: action-id is required${NC}"
  echo ""
  echo "Usage: $0 <action-id> [user-email] [user-group] [params-json]"
  echo ""
  echo "Available actions:"
  echo "  - summarize-docs"
  echo "  - generate-faq"
  echo "  - draft-change-note"
  echo "  - validate-schema"
  echo "  - create-jira-draft"
  echo "  - compliance-pack"
  echo ""
  exit 1
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  VaultMesh Q Business - Action Invocation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Action:  $ACTION"
echo "User:    $USER"
echo "Group:   $GROUP"
echo "Params:  $PARAMS"
echo ""

# Build payload
PAYLOAD=$(jq -n \
  --arg action "$ACTION" \
  --arg userId "$USER" \
  --arg group "$GROUP" \
  --argjson params "$PARAMS" \
  '{
    actionId: $action,
    user: { id: $userId, groups: [$group] },
    params: $params
  }')

echo -e "${YELLOW}Payload:${NC}"
echo "$PAYLOAD" | jq .
echo ""

# Invoke API
echo -e "${YELLOW}Invoking API...${NC}"
HTTP_CODE=$(curl -sS -w "%{http_code}" -o /tmp/action-response.json \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$API_BASE/api/actions/invoke")

echo ""

# Check response
if [[ "$HTTP_CODE" == "200" ]]; then
  echo -e "${GREEN}✓ Success (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo -e "${GREEN}Response:${NC}"
  jq . /tmp/action-response.json
elif [[ "$HTTP_CODE" == "403" ]]; then
  echo -e "${RED}✗ Forbidden (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo -e "${RED}Response:${NC}"
  jq . /tmp/action-response.json
else
  echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo -e "${RED}Response:${NC}"
  cat /tmp/action-response.json
fi

echo ""
