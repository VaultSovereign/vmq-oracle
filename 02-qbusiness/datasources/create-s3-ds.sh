#!/usr/bin/env bash
set -euo pipefail

# Accept args or env
APP_ID="${1:-${APP_ID:-}}"
INDEX_ID="${2:-${INDEX_ID:-}}"
: "${APP_ID:?Set APP_ID env var or pass as arg 1}"
: "${INDEX_ID:?Set INDEX_ID env var or pass as arg 2}"

REGION="${REGION:-eu-west-1}"
DS_NAME="${DS_NAME:-VaultMesh S3 KB}"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
ROLE_ARN="${ROLE_ARN:-}"

# Prepare configuration file (allows future templating)
CFG_SRC="02-qbusiness/datasources/s3-ds.json"
TMP_CFG=$(mktemp)
cp "$CFG_SRC" "$TMP_CFG"

DS_ID=$(aws qbusiness create-data-source \
  --region "$REGION" \
  --application-id "$APP_ID" \
  --index-id "$INDEX_ID" \
  --display-name "$DS_NAME" \
  ${ROLE_ARN:+--role-arn "$ROLE_ARN"} \
  --configuration "file://$TMP_CFG" \
  --query 'dataSourceId' --output text)

echo "DS_ID=$DS_ID"
