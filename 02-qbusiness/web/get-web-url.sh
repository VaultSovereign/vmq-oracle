#!/usr/bin/env bash
set -euo pipefail

APP_ID="${1:?Usage: $0 <APP_ID> [WEB_EXPERIENCE_ID]}"
WEB_EXPERIENCE_ID="${2:-}"
REGION="${REGION:-eu-west-1}"

# If no WEB_EXPERIENCE_ID provided, find it
if [ -z "$WEB_EXPERIENCE_ID" ]; then
    WEB_EXPERIENCE_ID=$(aws qbusiness list-web-experiences \
        --region "$REGION" \
        --application-id "$APP_ID" \
        --query 'webExperiences[0].webExperienceId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$WEB_EXPERIENCE_ID" = "None" ] || [ -z "$WEB_EXPERIENCE_ID" ]; then
        echo "❌ No web experience found. Create one first with:"
        echo "   ./02-qbusiness/web/create-web-experience.sh $APP_ID"
        exit 1
    fi
fi

# Get the URL
WEB_URL=$(aws qbusiness get-web-experience \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --web-experience-id "$WEB_EXPERIENCE_ID" \
    --query 'defaultEndpoint' \
    --output text)

echo "🔗 VaultMesh Q Assistant URL:"
echo "   $WEB_URL"
echo
echo "💡 Bookmark this URL and share with your team"
echo "   (Requires IAM Identity Center authentication)"