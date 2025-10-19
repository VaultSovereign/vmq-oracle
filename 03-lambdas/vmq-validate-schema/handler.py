import time
from common.vmq_common import authorize_action, ok, err, require

def handler(event, _ctx):
    event["_start_time"] = time.time()
    allowed, approval, deny = authorize_action(event)
    if not allowed and not approval:
        return err(403, deny, event)

    params, missing = require(event, "schemaUri")
    if missing:
        return err(400, f"missing required param(s): {', '.join(missing)}", event)

    profile = (params.get("profile") or "both").lower()
    report = {
        "profileEvaluated": profile,
        "issues": [],
        "summary": "No issues found in stub mode.",
    }
    return ok({"validationReport": report}, event)
