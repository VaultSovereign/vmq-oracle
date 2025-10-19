#!/usr/bin/env python3
"""
VaultMesh Q Business • Persona Resolution Helper
Usage: Resolve user groups → persona, fetch catalog, invoke actions.

Examples:
  # Resolve persona for a user
  python persona-helper.py resolve --groups VaultMesh-Engineering

  # Load and display catalog
  python persona-helper.py catalog

  # Invoke an action
  python persona-helper.py invoke --action summarize-docs \\
    --user alice@vaultmesh.io --group VaultMesh-Engineering \\
    --params '{"documentUris":["s3://..."]}'
"""
import json
import argparse
import boto3
import os
from typing import Dict, List, Optional

S3 = boto3.client("s3")
LAMBDA = boto3.client("lambda")
REGION = os.getenv("AWS_REGION", "eu-west-1")
BUCKET = os.getenv("EXPORT_BUCKET", "vaultmesh-knowledge-base")

# Lightweight group → persona mapping (pre-SSO fallback)
GROUP_TO_PERSONA = {
    "VaultMesh-Engineering": "engineer",
    "VaultMesh-Delivery": "delivery-manager",
    "VaultMesh-Compliance": "compliance",
    "VaultMesh-Management": "delivery-manager",  # Fallback
}

def resolve_persona(groups: List[str]) -> str:
    """Resolve first matching persona from user groups."""
    for g in groups:
        if g in GROUP_TO_PERSONA:
            return GROUP_TO_PERSONA[g]
    return "engineer"  # Default persona for anonymous/unknown

def load_persona_s3(persona_id: str) -> Dict:
    """Fetch persona definition from S3."""
    key = f"personas/{persona_id}.json"
    obj = S3.get_object(Bucket=BUCKET, Key=key)
    return json.loads(obj["Body"].read().decode("utf-8"))

def load_catalog_s3() -> Dict:
    """Fetch actions catalog from S3."""
    obj = S3.get_object(Bucket=BUCKET, Key="actions/catalog.json")
    return json.loads(obj["Body"].read().decode("utf-8"))

def invoke_action(
    action_id: str,
    user_id: str,
    user_group: str,
    params: Dict,
    request_id: Optional[str] = None,
) -> Dict:
    """
    Invoke a Lambda action with standard input contract.
    Returns the Lambda response payload.
    """
    catalog = load_catalog_s3()
    action_def = next((a for a in catalog["catalog"] if a["id"] == action_id), None)
    if not action_def:
        raise ValueError(f"Action {action_id} not found in catalog")

    lambda_arn = action_def["lambda"]
    fn_name = lambda_arn.split(":")[-1]

    persona_id = resolve_persona([user_group])

    payload = {
        "action": action_id,
        "user": {"id": user_id, "group": user_group},
        "context": {
            "request_id": request_id or f"cli-{int(__import__('time').time()*1000)}",
            "persona": persona_id,
        },
        "params": params,
    }

    resp = LAMBDA.invoke(
        FunctionName=fn_name,
        InvocationType="RequestResponse",
        Payload=json.dumps(payload).encode("utf-8"),
    )
    return json.loads(resp["Payload"].read().decode("utf-8"))


def main():
    parser = argparse.ArgumentParser(description="VaultMesh Q Persona & Action Helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # resolve command
    resolve_p = subparsers.add_parser("resolve", help="Resolve persona from groups")
    resolve_p.add_argument("--groups", nargs="+", required=True)

    # catalog command
    subparsers.add_parser("catalog", help="Display actions catalog")

    # invoke command
    invoke_p = subparsers.add_parser("invoke", help="Invoke an action")
    invoke_p.add_argument("--action", required=True, help="Action ID (e.g., summarize-docs)")
    invoke_p.add_argument("--user", required=True, help="User ID")
    invoke_p.add_argument("--group", required=True, help="User group")
    invoke_p.add_argument("--params", required=True, help="JSON params dict")
    invoke_p.add_argument("--request-id", help="Optional request ID")

    args = parser.parse_args()

    if args.command == "resolve":
        persona = resolve_persona(args.groups)
        persona_data = load_persona_s3(persona)
        print(json.dumps({"persona_id": persona, "data": persona_data}, indent=2))

    elif args.command == "catalog":
        catalog = load_catalog_s3()
        print(json.dumps(catalog, indent=2))

    elif args.command == "invoke":
        params = json.loads(args.params)
        result = invoke_action(
            action_id=args.action,
            user_id=args.user,
            user_group=args.group,
            params=params,
            request_id=args.request_id,
        )
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
