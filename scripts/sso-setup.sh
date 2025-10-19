#!/bin/bash
set -e

REGION=${REGION:-eu-west-1}
IDENTITY_STORE_ID="d-9367affd31"
SSO_INSTANCE_ARN="arn:aws:sso:::instance/ssoins-6804107edb4ae8eb"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VaultMesh Q Business - SSO Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# 1. Create groups
echo "→ Creating VaultMesh groups..."
for group in Engineering Delivery Management Compliance; do
  GROUP_NAME="VaultMesh-${group}"
  echo "  Creating: $GROUP_NAME"
  aws identitystore create-group \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --display-name "$GROUP_NAME" \
    --region "$REGION" 2>/dev/null || echo "  (already exists)"
done

echo
echo "→ Listing groups..."
aws identitystore list-groups \
  --identity-store-id "$IDENTITY_STORE_ID" \
  --region "$REGION" \
  --query 'Groups[?starts_with(DisplayName, `VaultMesh`)].{Name:DisplayName,ID:GroupId}' \
  --output table

echo
echo "✓ Groups created"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "1. Add users to groups via AWS Console:"
echo "   https://console.aws.amazon.com/singlesignon/home?region=$REGION"
echo
echo "2. Create Q Business SSO application:"
echo "   cd 02-qbusiness/app"
echo "   ./create-sso-app.sh"
echo
echo "3. Update Q Business to use SSO:"
echo "   ./update-to-sso.sh"
echo
