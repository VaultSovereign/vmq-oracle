#!/usr/bin/env bash
# VaultMesh Q Business • Persona & Action Helper (Bash/AWS CLI)
# Lightweight wrapper to resolve personas, load catalog, and invoke actions.

set -euo pipefail

REGION=${AWS_REGION:-eu-west-1}
BUCKET=${EXPORT_BUCKET:-vaultmesh-knowledge-base}

# Group → Persona mapping
resolve_persona() {
  local group="$1"
  case "$group" in
    VaultMesh-Engineering) echo "engineer" ;;
    VaultMesh-Delivery)    echo "delivery-manager" ;;
    VaultMesh-Compliance)  echo "compliance" ;;
    VaultMesh-Management)  echo "delivery-manager" ;;
    *)                     echo "engineer" ;; # Default
  esac
}

# Load persona from S3
load_persona() {
  local persona_id="$1"
  aws s3 cp "s3://${BUCKET}/personas/${persona_id}.json" - --region "$REGION" 2>/dev/null || echo "{}"
}

# Load catalog from S3
load_catalog() {
  aws s3 cp "s3://${BUCKET}/actions/catalog.json" - --region "$REGION"
}

# Invoke action
invoke_action() {
  local action_id="$1"
  local user_id="$2"
  local user_group="$3"
  local params="$4"
  local request_id="${5:-cli-$(date +%s)}"

  local persona_id
  persona_id=$(resolve_persona "$user_group")

  # Find Lambda function name from catalog
  local catalog
  catalog=$(load_catalog)
  local fn_name
  fn_name=$(echo "$catalog" | jq -r --arg aid "$action_id" '.catalog[] | select(.id==$aid) | .lambda' | awk -F: '{print $NF}')

  if [[ -z "$fn_name" ]]; then
    echo "Error: Action $action_id not found in catalog" >&2
    return 1
  fi

  # Build payload
  local payload
  payload=$(jq -n \
    --arg action "$action_id" \
    --arg uid "$user_id" \
    --arg grp "$user_group" \
    --arg rid "$request_id" \
    --arg persona "$persona_id" \
    --argjson params "$params" \
    '{
      action: $action,
      user: {id: $uid, group: $grp},
      context: {request_id: $rid, persona: $persona},
      params: $params
    }')

  # Invoke Lambda
  aws lambda invoke \
    --function-name "$fn_name" \
    --cli-binary-format raw-in-base64-out \
    --payload "$payload" \
    /tmp/lambda-out.json \
    --region "$REGION" >/dev/null

  cat /tmp/lambda-out.json
  rm -f /tmp/lambda-out.json
}

# CLI dispatch
cmd="${1:-help}"
shift || true

case "$cmd" in
  resolve)
    group="${1:?Usage: $0 resolve <group>}"
    persona=$(resolve_persona "$group")
    echo "Persona for group '$group': $persona"
    echo ""
    echo "Persona definition:"
    load_persona "$persona"
    ;;

  catalog)
    load_catalog | jq .
    ;;

  invoke)
    action="${1:?Usage: $0 invoke <action-id> <user-id> <group> '<params-json>'}"
    user_id="${2:?Missing user-id}"
    group="${3:?Missing group}"
    params="${4:?Missing params JSON}"
    request_id="${5:-}"
    invoke_action "$action" "$user_id" "$group" "$params" "$request_id" | jq .
    ;;

  *)
    cat <<EOF
VaultMesh Q Business • Persona & Action Helper

Usage:
  $0 resolve <group>                     Resolve persona from group
  $0 catalog                             Display actions catalog
  $0 invoke <action-id> <user-id> <group> '<params-json>' [request-id]

Examples:
  $0 resolve VaultMesh-Engineering
  $0 catalog
  $0 invoke summarize-docs alice@vaultmesh.io VaultMesh-Engineering '{"documentUris":["s3://test/doc.md"]}'
EOF
    ;;
esac
