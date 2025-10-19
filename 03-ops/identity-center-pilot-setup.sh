#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-eu-west-1}"

echo "→ Discovering Identity Center instance..."
read -r INSTANCE_ARN ID_STORE < <(aws sso-admin list-instances --region "$REGION" \
  --query 'Instances[0].[InstanceArn,IdentityStoreId]' --output text)

echo "  InstanceArn: $INSTANCE_ARN"
echo "  IdentityStoreId: $ID_STORE"

echo "→ Resolving group IDs..."
ENG_GROUP=$(aws identitystore list-groups --identity-store-id "$ID_STORE" \
  --filters AttributePath=DisplayName,AttributeValue=VaultMesh-Engineering \
  --query 'Groups[0].GroupId' --output text)
DELIV_GROUP=$(aws identitystore list-groups --identity-store-id "$ID_STORE" \
  --filters AttributePath=DisplayName,AttributeValue=VaultMesh-Delivery \
  --query 'Groups[0].GroupId' --output text)
MGMT_GROUP=$(aws identitystore list-groups --identity-store-id "$ID_STORE" \
  --filters AttributePath=DisplayName,AttributeValue=VaultMesh-Management \
  --query 'Groups[0].GroupId' --output text)
COMP_GROUP=$(aws identitystore list-groups --identity-store-id "$ID_STORE" \
  --filters AttributePath=DisplayName,AttributeValue=VaultMesh-Compliance \
  --query 'Groups[0].GroupId' --output text)

echo "  Engineering: $ENG_GROUP"
echo "  Delivery: $DELIV_GROUP"
echo "  Management: $MGMT_GROUP"
echo "  Compliance: $COMP_GROUP"

declare -A USERS=(
  [eng1@vaultmesh.org]="Eng:One:$ENG_GROUP"
  [eng2@vaultmesh.org]="Eng:Two:$ENG_GROUP"
  [deliv1@vaultmesh.org]="Deliv:One:$DELIV_GROUP"
  [deliv2@vaultmesh.org]="Deliv:Two:$DELIV_GROUP"
  [comp1@vaultmesh.org]="Comp:One:$COMP_GROUP"
)

for email in "${!USERS[@]}"; do
  IFS=: read -r given family group <<< "${USERS[$email]}"
  
  echo "→ Creating user $email..."
  USER_ID=$(aws identitystore create-user --identity-store-id "$ID_STORE" \
    --user-name "$email" --display-name "$given $family" \
    --name "GivenName=$given,FamilyName=$family" \
    --emails "Value=$email,Type=work,Primary=true" \
    --query 'UserId' --output text 2>/dev/null || \
    aws identitystore list-users --identity-store-id "$ID_STORE" \
      --filters "AttributePath=UserName,AttributeValue=$email" \
      --query 'Users[0].UserId' --output text)
  
  echo "  UserId: $USER_ID"
  
  echo "→ Adding to group $group..."
  aws identitystore create-group-membership --identity-store-id "$ID_STORE" \
    --group-id "$group" --member-id "UserId=$USER_ID" 2>/dev/null || echo "  (already member)"
done

echo "✓ Pilot users ready"
