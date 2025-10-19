#!/usr/bin/env bash
set -euo pipefail

# Accept args or env
APP_ID="${1:-${APP_ID:-}}"
INDEX_ID="${2:-${INDEX_ID:-}}"
: "${APP_ID:?Set APP_ID env var or pass as arg 1}"
: "${INDEX_ID:?Set INDEX_ID env var or pass as arg 2}"

REGION="${REGION:-eu-west-1}"
RETRIEVER_NAME="${RETRIEVER_NAME:-vaultmesh-retriever}"

RID="$(aws qbusiness create-retriever \
  --region "$REGION" \
  --application-id "$APP_ID" \
  --type NATIVE_INDEX \
  --display-name "$RETRIEVER_NAME" \
  --configuration "{\"nativeIndexConfiguration\":{\"indexId\":\"$INDEX_ID\"}}" \
  --query 'retrieverId' --output text)"

echo "RETRIEVER_ID=$RID"
