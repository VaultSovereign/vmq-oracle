#!/usr/bin/env bash
# RUBEDO Validation Script - Quick health check for all components
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"
BUCKET="vaultmesh-knowledge-base"
APP_ID="33b247da-92e9-42f4-a03e-892b28b51c21"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VaultMesh RUBEDO - System Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to check Lambda status
check_lambda() {
  local fn_name=$1
  echo -n "  → $fn_name: "
  if aws lambda get-function --function-name "$fn_name" --region "$REGION" &>/dev/null; then
    echo "✓ Deployed"
  else
    echo "✗ NOT FOUND"
    return 1
  fi
}

# Function to check S3 object
check_s3() {
  local key=$1
  local description=$2
  echo -n "  → $description: "
  if aws s3api head-object --bucket "$BUCKET" --key "$key" --region "$REGION" &>/dev/null; then
    echo "✓ Published"
  else
    echo "✗ NOT FOUND"
    return 1
  fi
}

# 1. Lambda Functions
echo "1. Lambda Functions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_lambda "vmq-summarize-docs"
check_lambda "vmq-generate-faq"
check_lambda "vmq-draft-change-note"
check_lambda "vmq-validate-schema"
check_lambda "vmq-create-jira-draft"
check_lambda "vmq-generate-compliance-pack"
echo ""

# 2. S3 Assets
echo "2. S3 Assets"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_s3 "actions/catalog.json" "Actions Catalog"
check_s3 "personas/engineer.json" "Persona: Engineer"
check_s3 "personas/delivery-manager.json" "Persona: Delivery Manager"
check_s3 "personas/compliance.json" "Persona: Compliance"
echo ""

# 3. CloudFormation Stack
echo "3. CloudFormation Stack"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -n "  → vmq-actions-rubedo: "
stack_status=$(aws cloudformation describe-stacks \
  --stack-name vmq-actions-rubedo \
  --region "$REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$stack_status" == "CREATE_COMPLETE" || "$stack_status" == "UPDATE_COMPLETE" ]]; then
  echo "✓ $stack_status"
else
  echo "✗ $stack_status"
fi
echo ""

# 4. Q Business App
echo "4. Q Business Application"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -n "  → App Status: "
app_status=$(aws qbusiness get-application \
  --application-id "$APP_ID" \
  --region "$REGION" \
  --query 'status' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$app_status" == "ACTIVE" ]]; then
  echo "✓ ACTIVE"
else
  echo "✗ $app_status"
fi
echo ""

# 5. Smoke Test (single action)
echo "5. Smoke Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -n "  → vmq-summarize-docs (authorized): "

TEST_EVENT=$(cat <<'EOF'
{
  "action": "summarize-docs",
  "user": {"id": "test@vaultmesh.io", "group": "VaultMesh-Engineering"},
  "context": {"request_id": "health-check", "persona": "engineer"},
  "params": {"documentUris": ["s3://test/doc.md"], "audience": "general"}
}
EOF
)

response=$(aws lambda invoke \
  --function-name vmq-summarize-docs \
  --cli-binary-format raw-in-base64-out \
  --payload "$TEST_EVENT" \
  --region "$REGION" \
  /tmp/rubedo-health.json 2>&1 || echo "ERROR")

if [[ "$response" == *"StatusCode\": 200"* ]]; then
  status_code=$(jq -r '.statusCode' /tmp/rubedo-health.json 2>/dev/null || echo "unknown")
  if [[ "$status_code" == "200" ]]; then
    echo "✓ PASS (200 OK)"
  else
    echo "✗ FAIL (HTTP $status_code)"
  fi
else
  echo "✗ FAIL (Lambda error)"
fi

echo -n "  → vmq-summarize-docs (unauthorized): "
TEST_EVENT_DENY=$(cat <<'EOF'
{
  "action": "summarize-docs",
  "user": {"id": "test@example.com", "group": "Unknown-Group"},
  "context": {"request_id": "health-check-deny"},
  "params": {"documentUris": ["s3://test/doc.md"]}
}
EOF
)

response=$(aws lambda invoke \
  --function-name vmq-summarize-docs \
  --cli-binary-format raw-in-base64-out \
  --payload "$TEST_EVENT_DENY" \
  --region "$REGION" \
  /tmp/rubedo-health-deny.json 2>&1 || echo "ERROR")

if [[ "$response" == *"StatusCode\": 200"* ]]; then
  status_code=$(jq -r '.statusCode' /tmp/rubedo-health-deny.json 2>/dev/null || echo "unknown")
  if [[ "$status_code" == "403" ]]; then
    echo "✓ PASS (403 Forbidden)"
  else
    echo "✗ FAIL (Expected 403, got $status_code)"
  fi
else
  echo "✗ FAIL (Lambda error)"
fi
echo ""

# 6. CloudWatch Logs
echo "6. CloudWatch Logs (Last 5 min)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -n "  → Recent events: "
recent_count=$(aws logs tail /aws/lambda/vmq-summarize-docs \
  --region "$REGION" \
  --since 5m \
  --format short 2>/dev/null | wc -l || echo "0")

echo "$recent_count events"
echo ""

# 7. Dashboard
echo "7. CloudWatch Dashboard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -n "  → VaultMesh-Sovereign: "
if aws cloudwatch get-dashboard \
  --dashboard-name VaultMesh-Sovereign \
  --region "$REGION" &>/dev/null; then
  echo "✓ Exists"
else
  echo "✗ NOT FOUND"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Validation Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  - View dashboard: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=VaultMesh-Sovereign"
echo "  - View logs: aws logs tail /aws/lambda/vmq-summarize-docs --region $REGION --follow"
echo "  - Test action: aws lambda invoke --function-name vmq-summarize-docs --payload file://test-event.json /tmp/out.json"
echo ""
