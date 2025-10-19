#!/usr/bin/env bash
set -euo pipefail

APP_ID="${1:-}"
if [[ -z "$APP_ID" ]]; then
  echo "Usage: $0 <APP_ID>" >&2
  exit 1
fi

REGION="${REGION:-eu-west-1}"
INDEX_NAME="${INDEX_NAME:-vaultmesh-index}"

INDEX_ID=$(aws qbusiness create-index \
  --region "$REGION" \
  --application-id "$APP_ID" \
  --display-name "$INDEX_NAME" \
  --type ENTERPRISE \
  --query 'indexId' --output text)

echo "INDEX_ID=$INDEX_ID"

