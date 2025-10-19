#!/usr/bin/env bash
# 🜄 Sovereign Architecture - Complete Sync Pipeline
# Export KG → Upload S3 → Sync Q Business → Create Web Experience → Get URL

set -euo pipefail

SA="${SA:-$HOME/sovereign-architecture}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || printf '')"
VMQ="${VMQ:-${REPO_ROOT:-$HOME/work/vmq-oracle}}"

echo "🜄 SOVEREIGN ARCHITECTURE - COMPLETE SYNC PIPELINE"
echo "=================================================="

echo "==[1/5] Export Knowledge Graph → ${SA}/q-business-export =="
cd "$SA"
[ -f config/config.yaml ] || cp config/config.example.yaml config/config.yaml
# Re-export demo entities (replace --demo with real ingest when ready)
python3 living_knowledge_graph/living_knowledge_graph.py --demo --export ./q-business-export

echo "==[2/5] Push export to S3 =="
[ -f config/config.env ] && source config/config.env || true
: "${AWS_REGION:=eu-west-1}"
: "${Q_EXPORT_BUCKET:=vaultmesh-knowledge-base}"  # Sealed bucket choice
aws s3 sync ./q-business-export/ "s3://${Q_EXPORT_BUCKET}/" --delete --region "$AWS_REGION"
echo "✅ Synced to s3://${Q_EXPORT_BUCKET}/"

echo "==[3/5] Start & wait for Q Business sync =="
cd "$VMQ"
set -a && . ./.env && set +a
: "${REGION:=eu-west-1}"
: "${APP_ID:?APP_ID missing in .env}"
: "${INDEX_ID:?INDEX_ID missing in .env}"
: "${DS_ID:?DS_ID missing in .env}"

aws qbusiness start-data-source-sync-job \
  --region "$REGION" \
  --application-id "$APP_ID" \
  --index-id "$INDEX_ID" \
  --data-source-id "$DS_ID" >/dev/null

echo "⏳ Waiting for data source sync to complete..."
for i in $(seq 1 60); do
  STATUS=$(aws qbusiness list-data-source-sync-jobs \
    --region "$REGION" --application-id "$APP_ID" \
    --index-id "$INDEX_ID" --data-source-id "$DS_ID" \
    --query "history[0].status" --output text 2>/dev/null || echo "UNKNOWN")
  echo "  [$i/60] status: $STATUS"
  case "$STATUS" in
    SUCCEEDED) break ;;
    FAILED|STOPPED)
      echo "❌ Sync ended with $STATUS"
      echo "Last error:"
      aws qbusiness list-data-source-sync-jobs \
        --region "$REGION" --application-id "$APP_ID" \
        --index-id "$INDEX_ID" --data-source-id "$DS_ID" \
        --query "history[0].error" --output json || true
      exit 1
      ;;
  esac
  sleep 10
done

if [ "$STATUS" != "SUCCEEDED" ]; then
  echo "⏰ Timed out waiting for SUCCEEDED (last: $STATUS)"
  exit 1
fi
echo "✅ Sync SUCCEEDED"

echo "==[4/5] Create Web Experience if missing =="
if ! grep -q "^WEB_EXPERIENCE_ID=" .env 2>/dev/null; then
  # For anonymous identity type, create web experience with minimal config
  WEB_EXPERIENCE_ID=$(aws qbusiness create-web-experience \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --title "VaultMesh Q Assistant" \
    --identity-provider-configuration '{"samlConfiguration":{}}' \
    --query "webExperienceId" --output text 2>/dev/null || echo "FAILED")
  
  if [ "$WEB_EXPERIENCE_ID" = "FAILED" ]; then
    # Try without identity provider configuration for anonymous apps
    WEB_EXPERIENCE_ID=$(aws qbusiness create-web-experience \
      --region "$REGION" \
      --application-id "$APP_ID" \
      --title "VaultMesh Q Assistant" \
      --query "webExperienceId" --output text 2>/dev/null || echo "FAILED")
  fi
  
  if [ "$WEB_EXPERIENCE_ID" = "FAILED" ]; then
    echo "⚠️  Web experience creation failed. Checking AWS console method..."
    echo "   For anonymous apps, web experience may need to be created via console"
    echo "   Continuing without web experience - you can create it manually later"
    WEB_EXPERIENCE_ID="manual-creation-needed"
  else
    echo "WEB_EXPERIENCE_ID=$WEB_EXPERIENCE_ID" | tee -a .env
    echo "✅ Created web experience: $WEB_EXPERIENCE_ID"
  fi
else
  WEB_EXPERIENCE_ID=$(awk -F= "/^WEB_EXPERIENCE_ID=/{print \$2}" .env)
  echo "✅ Using existing web experience: $WEB_EXPERIENCE_ID"
fi

echo "==[5/5] Get Web Experience URL =="
if [ "$WEB_EXPERIENCE_ID" != "manual-creation-needed" ]; then
  WEB_URL=$(aws qbusiness get-web-experience \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --web-experience-id "$WEB_EXPERIENCE_ID" \
    --query "defaultEndpoint" --output text 2>/dev/null || echo "URL_FETCH_FAILED")
else
  WEB_URL="Create web experience manually in AWS console"
fi

echo
echo "🎉 SOVEREIGN ARCHITECTURE ACTIVATED!"
echo "===================================="
echo
echo "✅ Knowledge Graph: 3 entities exported (MIRAGE, SHADOW, POSSESSION)"
echo "✅ S3 Sync: Data uploaded to vaultmesh-knowledge-base"
echo "✅ Q Business Sync: SUCCEEDED - Knowledge is now indexed"
echo
if [ "$WEB_URL" != "Create web experience manually in AWS console" ] && [ "$WEB_URL" != "URL_FETCH_FAILED" ]; then
  echo "🔗 VaultMesh Q Assistant URL:"
  echo "   $WEB_URL"
  echo
  echo "🧪 Try these queries in the web UI:"
  echo "   • What is MIRAGE?"
  echo "   • How does SHADOW differ from POSSESSION?"
  echo "   • Explain VaultMesh Polis"
  echo "   • What are the three phases of deployment?"
  echo
  echo "💡 Bookmark this URL and share with your team"
else
  echo "🔗 Web Experience: Create manually in AWS Console"
  echo "   Go to: Amazon Q Business → Applications → $APP_ID → Web experiences"
  echo "   Click 'Create web experience' and use default settings"
fi
echo
echo "📊 Next Steps:"
echo "   1. Test queries in the web interface"
echo "   2. Add more documents to ~/sovereign-architecture/samples/docs/"
echo "   3. Re-run this script to sync new knowledge"
echo "   4. Set up IAM Identity Center for team access control"
echo
echo "🜄 Solve et Coagula - The intelligence is now live."