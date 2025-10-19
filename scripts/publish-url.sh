#!/usr/bin/env bash
# Get and display the Amazon Q Business web experience URL

set -euo pipefail

cd "$(dirname "$0")/.."
set -a && . ./.env && set +a

: "${REGION:=eu-west-1}"
: "${APP_ID:?APP_ID missing in .env}"

# Find web experience ID if not in .env
if ! grep -q "^WEB_EXPERIENCE_ID=" .env 2>/dev/null; then
    WEB_EXPERIENCE_ID=$(aws qbusiness list-web-experiences \
        --region "$REGION" --application-id "$APP_ID" \
        --query 'webExperiences[0].webExperienceId' --output text 2>/dev/null || echo "None")
    
    if [ "$WEB_EXPERIENCE_ID" = "None" ] || [ -z "$WEB_EXPERIENCE_ID" ]; then
        echo "❌ No web experience found. Create one first:"
        echo "   AWS Console → Amazon Q Business → Applications → $APP_ID → Web experiences"
        exit 1
    fi
    
    echo "WEB_EXPERIENCE_ID=$WEB_EXPERIENCE_ID" >> .env
else
    WEB_EXPERIENCE_ID=$(awk -F= '/^WEB_EXPERIENCE_ID=/{print $2}' .env)
fi

# Get the URL
WEB_URL=$(aws qbusiness get-web-experience \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --web-experience-id "$WEB_EXPERIENCE_ID" \
    --query 'defaultEndpoint' --output text)

echo
echo "🔗 VaultMesh Q Assistant"
echo "========================"
echo
echo "URL: $WEB_URL"
echo "App ID: $APP_ID"
echo "Web Experience ID: $WEB_EXPERIENCE_ID"
echo "Region: $REGION"
echo
echo "🧪 Test Queries:"
echo "   • What is MIRAGE?"
echo "   • How does SHADOW differ from POSSESSION?"
echo "   • Explain VaultMesh Polis mining extension"
echo
echo "🛡️  Security: Anonymous access enabled"
echo "💡 Tip: Set up IAM Identity Center for team access control"
echo
echo "📋 Share this URL with your team:"
echo "$WEB_URL"