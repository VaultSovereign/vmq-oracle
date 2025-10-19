import time
from common.vmq_common import authorize_action, ok, err, require

def handler(event, _ctx):
    event["_start_time"] = time.time()
    allowed, approval, deny = authorize_action(event)
    if not allowed and not approval:
        return err(403, deny, event)

    params, missing = require(event, "projectKey", "summary", "description")
    if missing:
        return err(400, f"missing required param(s): {', '.join(missing)}", event)

    payload = {
        "project": {"key": params["projectKey"]},
        "summary": params["summary"],
        "description": params["description"],
        "labels": params.get("labels") or [],
        "dryRun": True,
        "approverRequired": True,
    }
    return ok({"jiraPayload": payload}, event)
