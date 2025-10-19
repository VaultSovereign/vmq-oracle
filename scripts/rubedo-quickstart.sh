#!/usr/bin/env bash
# RUBEDO Actions System • Quick Start & Common Commands
set -euo pipefail

REGION=${AWS_REGION:-eu-west-1}
BUCKET=${EXPORT_BUCKET:-vaultmesh-knowledge-base}

cat <<'BANNER'
╔════════════════════════════════════════════════════════════╗
║  VaultMesh Q Business • RUBEDO Actions System              ║
║  Quick Start Commands                                      ║
╚════════════════════════════════════════════════════════════╝
BANNER

echo ""
echo "📋 SYSTEM STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Region:         $REGION"
echo "Bucket:         $BUCKET"
echo "Stack:          vmq-actions-rubedo"
echo "Dashboard:      VaultMesh-Sovereign"
echo ""

# Check stack status
echo "CloudFormation Stack Status:"
aws cloudformation describe-stacks \
  --stack-name vmq-actions-rubedo \
  --region "$REGION" \
  --query 'Stacks[0].[StackName,StackStatus]' \
  --output text 2>/dev/null || echo "  Stack not found or error accessing"

echo ""
echo "📦 DEPLOYED FUNCTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws lambda list-functions \
  --region "$REGION" \
  --query 'Functions[?starts_with(FunctionName, `vmq-`)].[FunctionName,Runtime,LastModified]' \
  --output table 2>/dev/null

echo ""
echo "📊 CATALOG STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws s3 ls "s3://${BUCKET}/actions/catalog.json" --region "$REGION" 2>/dev/null || echo "  Catalog not found"
echo ""
echo "Actions available:"
aws s3 cp "s3://${BUCKET}/actions/catalog.json" - --region "$REGION" 2>/dev/null | \
  jq -r '.catalog[] | "  • \(.id) (\(.safetyTier))"' || echo "  Error reading catalog"

echo ""
echo "🎭 PERSONAS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws s3 ls "s3://${BUCKET}/personas/" --region "$REGION" | awk '{print "  • " $NF}'

echo ""
echo "📈 RECENT METRICS (Last 1h)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
start_time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v -1H +%Y-%m-%dT%H:%M:%S)

aws cloudwatch get-metric-statistics \
  --namespace VaultMesh/QBusinessActions \
  --metric-name ActionsInvoked \
  --start-time "$start_time" \
  --end-time "$end_time" \
  --period 3600 \
  --statistics Sum \
  --region "$REGION" \
  --query 'Datapoints[0].Sum' \
  --output text 2>/dev/null | \
  awk '{printf "  Total Actions: %s\n", ($1 == "" || $1 == "None") ? "0" : $1}'

echo ""
echo "🔧 QUICK COMMANDS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat <<'COMMANDS'
# Test action invocation (authorized)
./scripts/persona-helper.sh invoke \
  summarize-docs \
  alice@vaultmesh.io \
  VaultMesh-Engineering \
  '{"documentUris":["s3://vaultmesh-knowledge-base/convergence/manifesto.md"]}'

# Resolve persona for a group
./scripts/persona-helper.sh resolve VaultMesh-Engineering

# View catalog
./scripts/persona-helper.sh catalog | jq '.catalog[] | {id, name, safetyTier}'

# View recent logs
aws logs tail /aws/lambda/vmq-summarize-docs \
  --since 30m --region eu-west-1 --format short

# View CloudWatch dashboard
echo "https://console.aws.amazon.com/cloudwatch/deeplink.js?region=eu-west-1#dashboards:name=VaultMesh-Sovereign"

# Re-deploy Lambdas
cd 03-lambdas && ./deploy.sh

# Update catalog
sed 's/${AWS_REGION}/eu-west-1/g; s/${AWS_ACCOUNT_ID}/509399262563/g' \
  02-qbusiness/actions/actions-catalog.json | \
  aws s3 cp - s3://vaultmesh-knowledge-base/actions/catalog.json \
  --region eu-west-1 --cache-control no-cache
COMMANDS

echo ""
echo "📖 DOCUMENTATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Integration Guide:  02-qbusiness/actions/RUBEDO-INTEGRATION.md"
echo "  Actions Catalog:    02-qbusiness/actions/README.md"
echo "  Personas Guide:     02-qbusiness/personas/README.md"
echo "  OPA Policy:         02-qbusiness/guardrails/opa/actions.rego"
echo ""
echo "✨ RUBEDO Actions System Ready"
echo ""
