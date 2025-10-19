#!/usr/bin/env bash
# Final end-to-end validation for RUBEDO deployment
set -euo pipefail

REGION=eu-west-1
PASS=0
FAIL=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RUBEDO - Final End-to-End Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test each action
actions=(
  "summarize-docs"
  "generate-faq"
  "draft-change-note"
  "validate-schema"
  "create-jira-draft"
  "compliance-pack"
)

echo "Testing all 6 actions with authorized user..."
echo ""

for action in "${actions[@]}"; do
  echo -n "  → $action: "

  payload="{\"action\":\"$action\",\"user\":{\"id\":\"test@vaultmesh.io\",\"group\":\"VaultMesh-Engineering\"},\"context\":{\"request_id\":\"final-$action\"},\"params\":{}}"

  result=$(aws lambda invoke \
    --function-name "vmq-$action" \
    --cli-binary-format raw-in-base64-out \
    --payload "$payload" \
    --region "$REGION" \
    "/tmp/final-$action.json" 2>&1 || echo "ERROR")

  if echo "$result" | grep -q '"StatusCode": 200'; then
    status=$(jq -r '.statusCode' "/tmp/final-$action.json" 2>/dev/null || echo "unknown")
    if [[ "$status" == "200" ]]; then
      echo "✓ PASS (200 OK)"
      ((PASS++))
    else
      echo "✗ FAIL (HTTP $status)"
      ((FAIL++))
    fi
  else
    echo "✗ FAIL (Lambda error)"
    ((FAIL++))
  fi
done

echo ""
echo "Testing authorization denial..."
echo ""

echo -n "  → Unauthorized user: "
payload='{"action":"summarize-docs","user":{"id":"eve@example.com","group":"Unknown-Group"},"context":{"request_id":"deny-test"},"params":{}}'

result=$(aws lambda invoke \
  --function-name "vmq-summarize-docs" \
  --cli-binary-format raw-in-base64-out \
  --payload "$payload" \
  --region "$REGION" \
  "/tmp/final-deny.json" 2>&1 || echo "ERROR")

if echo "$result" | grep -q '"StatusCode": 200'; then
  status=$(jq -r '.statusCode' "/tmp/final-deny.json" 2>/dev/null || echo "unknown")
  if [[ "$status" == "403" ]]; then
    echo "✓ PASS (403 Forbidden)"
    ((PASS++))
  else
    echo "✗ FAIL (Expected 403, got $status)"
    ((FAIL++))
  fi
else
  echo "✗ FAIL (Lambda error)"
  ((FAIL++))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ✓ Passed: $PASS"
echo "  ✗ Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED - READY FOR DEPLOYMENT"
  echo ""
  exit 0
else
  echo "❌ SOME TESTS FAILED - REVIEW BEFORE DEPLOYMENT"
  echo ""
  exit 1
fi
