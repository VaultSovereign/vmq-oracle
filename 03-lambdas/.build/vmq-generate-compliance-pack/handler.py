import time
import os
from common.vmq_common import authorize_action, ok, err, require

EXPORT_BUCKET = os.getenv("EXPORT_BUCKET", "vaultmesh-knowledge-base")

def handler(event, _ctx):
    event["_start_time"] = time.time()
    allowed, approval, deny = authorize_action(event)
    if not allowed and not approval:
        return err(403, deny, event)

    params, missing = require(event, "sourceUris")
    if missing:
        return err(400, f"missing required param(s): {', '.join(missing)}", event)

    regime = params.get("regime", "ISO27k")
    rid = (event.get("context") or {}).get("request_id") or "stub"
    pkg_uri = f"s3://{EXPORT_BUCKET}/packages/{rid}.zip"

    cover = f"""# Compliance Pack (STUB)
**Regime:** {regime}

## Contents
- (stub) Collected {len(params['sourceUris'])} referenced documents
- (stub) Included a README with provenance and guardrail notes

## Provenance & Controls
- Guardrails: credentials-and-secrets, confidential-business-info (active)
- OPA Gate: vaultmesh.actions.* (green only)

**Package URI:** {pkg_uri}
"""
    return ok({"packageUri": pkg_uri, "coverMarkdown": cover}, event)
