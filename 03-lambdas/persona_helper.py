#!/usr/bin/env python3
"""
VaultMesh Q Business - Persona & Action Helper
Minimal helper to:
1. Resolve persona from user groups
2. Load persona JSON from S3 (with 5-min cache)
3. Load actions catalog
4. Present handoff choices and invoke Lambda actions
"""
import json
import time
import os
from typing import Dict, Optional, List
try:
    import boto3
    S3 = boto3.client('s3')
    LAMBDA = boto3.client('lambda')
except ImportError:
    print("Warning: boto3 not available, running in mock mode")
    S3 = None
    LAMBDA = None

BUCKET = os.getenv("EXPORT_BUCKET", "vaultmesh-knowledge-base")
PERSONA_PREFIX = "personas"
CATALOG_KEY = "actions/catalog.json"
CACHE_TTL = 300  # 5 minutes

_cache = {}

def resolve_persona(user_groups: List[str]) -> str:
    """
    Map Identity Center group to persona ID.
    Default to 'engineer' for Anonymous or unmapped groups.
    """
    group_mapping = {
        "VaultMesh-Engineering": "engineer",
        "VaultMesh-Delivery": "delivery-manager",
        "VaultMesh-Compliance": "compliance",
        "VaultMesh-Management": "delivery-manager",  # fallback for management
    }

    for group in user_groups:
        if group in group_mapping:
            return group_mapping[group]

    # Default to engineer for Anonymous or unknown groups
    return "engineer"

def load_persona_s3(persona_id: str) -> Optional[Dict]:
    """
    Load persona JSON from S3 with 5-minute caching.
    Returns None if not found or on error.
    """
    cache_key = f"persona:{persona_id}"
    now = time.time()

    # Check cache
    if cache_key in _cache:
        data, ts = _cache[cache_key]
        if now - ts < CACHE_TTL:
            return data

    # Fetch from S3
    if not S3:
        print(f"Mock mode: would load s3://{BUCKET}/{PERSONA_PREFIX}/{persona_id}.json")
        return {
            "id": persona_id,
            "tone": "professional",
            "preferred_sources": [],
            "answer_guidance": "Provide clear, technical answers",
            "glossary_aliases": {}
        }

    try:
        key = f"{PERSONA_PREFIX}/{persona_id}.json"
        response = S3.get_object(Bucket=BUCKET, Key=key)
        data = json.loads(response['Body'].read().decode('utf-8'))
        _cache[cache_key] = (data, now)
        return data
    except Exception as e:
        print(f"Error loading persona {persona_id}: {e}")
        return None

def load_catalog() -> Optional[Dict]:
    """
    Load actions catalog from S3 with 5-minute caching.
    """
    cache_key = "catalog"
    now = time.time()

    # Check cache
    if cache_key in _cache:
        data, ts = _cache[cache_key]
        if now - ts < CACHE_TTL:
            return data

    # Fetch from S3
    if not S3:
        print(f"Mock mode: would load s3://{BUCKET}/{CATALOG_KEY}")
        return {"version": "1.0.0-rubedo", "catalog": []}

    try:
        response = S3.get_object(Bucket=BUCKET, Key=CATALOG_KEY)
        data = json.loads(response['Body'].read().decode('utf-8'))
        _cache[cache_key] = (data, now)
        return data
    except Exception as e:
        print(f"Error loading catalog: {e}")
        return None

def get_handoff_choices(persona_id: str) -> List[Dict]:
    """
    Return list of available actions as handoff choices.
    Each choice includes: id, handoffText, description, lambda ARN
    """
    catalog = load_catalog()
    if not catalog:
        return []

    choices = []
    for action in catalog.get("catalog", []):
        invocation = action.get("invocation", {})
        choices.append({
            "id": action["id"],
            "name": action["name"],
            "handoffText": invocation.get("handoffText", action["name"]),
            "description": action["description"],
            "lambda": action["lambda"],
            "safetyTier": action.get("safetyTier", "UNKNOWN"),
        })

    return choices

def invoke_action(action_id: str, user: Dict, params: Dict, context: Optional[Dict] = None) -> Dict:
    """
    Invoke a Lambda action with the standard input contract.

    Input contract:
    {
      "action": "action-id",
      "user": {"id": "...", "group": "..."},
      "context": {"request_id": "...", "persona": "..."},
      "params": {...}
    }

    Returns Lambda response payload or error dict.
    """
    catalog = load_catalog()
    if not catalog:
        return {"error": "catalog unavailable"}

    # Find action in catalog
    action_meta = None
    for a in catalog.get("catalog", []):
        if a["id"] == action_id:
            action_meta = a
            break

    if not action_meta:
        return {"error": f"action {action_id} not found in catalog"}

    lambda_arn = action_meta["lambda"]

    # Build event payload
    event = {
        "action": action_id,
        "user": user,
        "context": context or {},
        "params": params,
    }

    if not LAMBDA:
        print(f"Mock mode: would invoke {lambda_arn} with {json.dumps(event, indent=2)}")
        return {"mock": True, "action": action_id}

    # Invoke Lambda
    try:
        response = LAMBDA.invoke(
            FunctionName=lambda_arn,
            InvocationType='RequestResponse',
            Payload=json.dumps(event).encode('utf-8')
        )

        result = json.loads(response['Payload'].read().decode('utf-8'))

        # Parse Lambda response body if present
        if 'body' in result:
            try:
                result['body'] = json.loads(result['body'])
            except:
                pass

        return result
    except Exception as e:
        return {"error": str(e)}

def init_session_with_persona(user_groups: List[str]) -> Dict:
    """
    Initialize chat session with persona context.
    Returns persona data and injected system prompt extras.
    """
    persona_id = resolve_persona(user_groups)
    persona = load_persona_s3(persona_id)

    if not persona:
        # Fallback to minimal default
        persona = {
            "id": persona_id,
            "tone": "professional",
            "preferred_sources": [],
            "answer_guidance": "Provide clear answers",
            "glossary_aliases": {}
        }

    # Extract pieces for injection into Q session
    system_prompt_extras = {
        "tone": persona.get("tone", "professional"),
        "preferred_sources": persona.get("preferred_sources", []),
        "answer_guidance": persona.get("answer_guidance", ""),
        "glossary_aliases": persona.get("glossary_aliases", {}),
    }

    return {
        "persona_id": persona_id,
        "persona": persona,
        "system_prompt_extras": system_prompt_extras,
    }

# CLI usage example
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage:")
        print("  persona_helper.py resolve <group1> [group2...]   - Resolve persona from groups")
        print("  persona_helper.py load <persona_id>              - Load persona JSON")
        print("  persona_helper.py catalog                        - Show action catalog")
        print("  persona_helper.py handoffs <persona_id>          - List handoff choices")
        print("  persona_helper.py invoke <action_id> <user_json> <params_json> - Invoke action")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "resolve":
        groups = sys.argv[2:]
        persona_id = resolve_persona(groups)
        print(f"Resolved persona: {persona_id}")

    elif cmd == "load":
        persona_id = sys.argv[2]
        persona = load_persona_s3(persona_id)
        print(json.dumps(persona, indent=2))

    elif cmd == "catalog":
        catalog = load_catalog()
        print(json.dumps(catalog, indent=2))

    elif cmd == "handoffs":
        persona_id = sys.argv[2]
        choices = get_handoff_choices(persona_id)
        print(json.dumps(choices, indent=2))

    elif cmd == "invoke":
        action_id = sys.argv[2]
        user = json.loads(sys.argv[3])
        params = json.loads(sys.argv[4])
        result = invoke_action(action_id, user, params)
        print(json.dumps(result, indent=2))

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
