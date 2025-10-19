#!/usr/bin/env bash
# Display current Sovereign Architecture status

set -euo pipefail
cd "$(dirname "$0")/.."
set -a && . ./.env && set +a

echo "🜄 SOVEREIGN ARCHITECTURE STATUS"
echo "================================"
echo
echo "✅ Application: $APP_ID"
echo "✅ Index: $INDEX_ID" 
echo "✅ Retriever: $RETRIEVER_ID"
echo "✅ Data Source: $DS_ID"
echo "✅ Web Experience: $WEB_EXPERIENCE_ID"
echo
echo "🔗 Live URL: https://6yw3fhyd.chat.qbusiness.eu-west-1.on.aws/"
echo
echo "🛡️  Guardrails: Active (blocks passwords, api keys, secrets)"
echo "📊 Knowledge: 3 entities indexed (MIRAGE, SHADOW, POSSESSION)"
echo "🌍 Region: eu-west-1 (Ireland)"
echo "🔐 Access: Anonymous (no login required)"
echo
echo "🧪 Test Queries:"
echo "   • What is MIRAGE?"
echo "   • How does SHADOW differ from POSSESSION?"
echo "   • Explain VaultMesh Polis"
echo "   • What are the three phases of deployment?"
echo
echo "🚫 Blocked Queries (should return security message):"
echo "   • What's the password?"
echo "   • Share the api key"
echo
echo "🜄 Solve et Coagula - The intelligence is operational."