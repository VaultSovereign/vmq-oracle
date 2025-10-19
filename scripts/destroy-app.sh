#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-eu-west-1}"

[ -f .env ] && set -a && . ./.env && set +a

if [ -z "${APP_ID:-}" ]; then
  echo "❌ APP_ID not found in .env"
  exit 1
fi

echo "🗑️  Deleting Q Business application: $APP_ID"

# Delete web experience
if [ -n "${WEB_EXPERIENCE_ID:-}" ]; then
  echo "  → Deleting web experience $WEB_EXPERIENCE_ID..."
  aws qbusiness delete-web-experience \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --web-experience-id "$WEB_EXPERIENCE_ID" 2>/dev/null || true
fi

# Delete data source
if [ -n "${DS_ID:-}" ] && [ -n "${INDEX_ID:-}" ]; then
  echo "  → Deleting data source $DS_ID..."
  aws qbusiness delete-data-source \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --index-id "$INDEX_ID" \
    --data-source-id "$DS_ID" 2>/dev/null || true
fi

# Delete retriever
if [ -n "${RETRIEVER_ID:-}" ]; then
  echo "  → Deleting retriever $RETRIEVER_ID..."
  aws qbusiness delete-retriever \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --retriever-id "$RETRIEVER_ID" 2>/dev/null || true
fi

# Delete index
if [ -n "${INDEX_ID:-}" ]; then
  echo "  → Deleting index $INDEX_ID..."
  aws qbusiness delete-index \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --index-id "$INDEX_ID" 2>/dev/null || true
fi

# Wait for resources to delete
echo "  → Waiting 30s for resources to clean up..."
sleep 30

# Delete application
echo "  → Deleting application $APP_ID..."
aws qbusiness delete-application \
  --region "$REGION" \
  --application-id "$APP_ID"

echo "✅ Application deleted. Cleaning .env..."

# Remove IDs from .env
sed -i.bak '/^APP_ID=/d; /^INDEX_ID=/d; /^RETRIEVER_ID=/d; /^DS_ID=/d; /^WEB_EXPERIENCE_ID=/d' .env

echo "✅ Done. Run 'make app' to start fresh."
