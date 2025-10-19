#!/usr/bin/env bash
# sovereign-sync-docs — One-shot: docs → S3 → Q Business sync → poll
# Usage: sovereign-sync-docs [--docs-path /path/to/docs] [--no-wait]

set -euo pipefail

# Config
DOCS_PATH="${1:-.}"
WAIT_POLL="${2:-true}"
VMQ="${HOME}/work/vm-business-q"
TMP_EXPORT="/tmp/q-business-export"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${CYAN}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# 1) Load Q Business environment
log_info "Loading Q Business environment..."
if [[ ! -f "$VMQ/.env" ]]; then
  log_err "$VMQ/.env not found. Run 'make app' first."
fi
cd "$VMQ"
set -a && . ./.env && set +a

# 2) Prepare docs
log_info "Preparing docs from: $DOCS_PATH"
rm -rf "$TMP_EXPORT"
mkdir -p "$TMP_EXPORT"

# If docs_path is a directory, copy all .md files
if [[ -d "$DOCS_PATH" ]]; then
  find "$DOCS_PATH" -name "*.md" -exec cp {} "$TMP_EXPORT/" \;
elif [[ -f "$DOCS_PATH" ]]; then
  cp "$DOCS_PATH" "$TMP_EXPORT/"
else
  log_err "Docs path not found: $DOCS_PATH"
fi

DOC_COUNT=$(find "$TMP_EXPORT" -name "*.md" | wc -l)
[[ $DOC_COUNT -eq 0 ]] && log_err "No .md files found in $DOCS_PATH"
log_ok "Staged $DOC_COUNT documents"

# 3) Push to S3
log_info "Syncing docs to S3://vaultmesh-knowledge-base/..."
aws s3 sync "$TMP_EXPORT/" "s3://${BUCKET_NAME}/" --delete --region "$REGION" --quiet
log_ok "S3 sync complete"

# 4) Start Q Business sync
log_info "Starting Q Business data source sync..."
SYNC_ID=$(aws qbusiness start-data-source-sync-job \
  --region "$REGION" \
  --application-id "$APP_ID" \
  --index-id "$INDEX_ID" \
  --data-source-id "$DS_ID" \
  --query "executionId" --output text)
log_ok "Sync job started: $SYNC_ID"

# 5) Poll (optional)
if [[ "$WAIT_POLL" == "false" ]]; then
  log_info "Skipping poll (--no-wait). Check status with:"
  echo "  aws qbusiness list-data-source-sync-jobs --region $REGION --application-id $APP_ID --index-id $INDEX_ID --data-source-id $DS_ID --query 'history[0]' --output json"
  exit 0
fi

log_info "Polling sync status (max 10 min)..."
for i in $(seq 1 100); do
  result=$(aws qbusiness list-data-source-sync-jobs \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --index-id "$INDEX_ID" \
    --data-source-id "$DS_ID" \
    --query "history[0].[status,itemsScanned,itemsIndexed,dataSourceErrorCode]" \
    --output text 2>/dev/null || echo "UNKNOWN ? ? ?")
  
  status=$(echo "$result" | awk '{print $1}')
  printf "[%2d/100] %s\n" "$i" "$result"
  
  if [[ "$status" =~ ^(SUCCEEDED|FAILED|STOPPED)$ ]]; then
    break
  fi
  sleep 6
done

echo ""
if [[ "$status" == "SUCCEEDED" ]]; then
  log_ok "Sync SUCCEEDED!"
  echo ""
  echo "=== Job Summary ==="
  aws qbusiness list-data-source-sync-jobs \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --index-id "$INDEX_ID" \
    --data-source-id "$DS_ID" \
    --query "history[0].[executionId,status,itemsScanned,itemsIndexed,itemsFailed,dataSourceErrorCode]" \
    --output table
  echo ""
  log_ok "Ready to query! Open:"
  aws qbusiness get-web-experience \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --web-experience-id "$WEB_EXPERIENCE_ID" \
    --query defaultEndpoint --output text
else
  log_warn "Sync status: $status"
  echo "Full details:"
  aws qbusiness list-data-source-sync-jobs \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --index-id "$INDEX_ID" \
    --data-source-id "$DS_ID" \
    --query "history[0]" --output json
  exit 1
fi
