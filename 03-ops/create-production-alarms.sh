#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-eu-west-1}"

FUNCTIONS=(
  vmq-summarize-docs
  vmq-generate-faq
  vmq-draft-change-note
  vmq-validate-schema
  vmq-create-jira-draft
  vmq-generate-compliance-pack
)

echo "→ Creating Lambda error alarms..."
for fn in "${FUNCTIONS[@]}"; do
  aws cloudwatch put-metric-alarm --region "$REGION" \
    --alarm-name "VMQ-Errors-$fn" \
    --metric-name Errors --namespace AWS/Lambda \
    --dimensions Name=FunctionName,Value="$fn" \
    --statistic Sum --period 300 --evaluation-periods 1 \
    --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold
  echo "  ✓ VMQ-Errors-$fn"
done

echo "→ Creating composite error alarm..."
RULE=$(printf 'ALARM("VMQ-Errors-%s") OR ' "${FUNCTIONS[@]}" | sed 's/ OR $//')
aws cloudwatch put-composite-alarm --region "$REGION" \
  --alarm-name "VMQ-Errors-Any" \
  --alarm-description "Any vmq-* lambda Errors > 0 (5m)" \
  --alarm-rule "$RULE"
echo "  ✓ VMQ-Errors-Any"

echo "→ Creating latency p95 alarms..."
for fn in "${FUNCTIONS[@]}"; do
  ACTION_ID="${fn#vmq-}"
  aws cloudwatch put-metric-alarm --region "$REGION" \
    --alarm-name "VMQ-LatencyP95-$ACTION_ID" \
    --metric-name ActionLatency --namespace VaultMesh/QBusinessActions \
    --dimensions Name=ActionId,Value="$ACTION_ID" \
    --extended-statistic p95 --period 300 --evaluation-periods 1 \
    --threshold 800 --comparison-operator GreaterThanThreshold
  echo "  ✓ VMQ-LatencyP95-$ACTION_ID"
done

echo "✓ Production alarms deployed"
