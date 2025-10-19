import time
from common.vmq_common import authorize_action, ok, err, require

def handler(event, _ctx):
    event["_start_time"] = time.time()
    allowed, approval, deny = authorize_action(event)
    if not allowed and not approval:
        return err(403, deny or "denied", event)

    params, missing = require(event, "documentUris")
    if missing:
        return err(400, f"missing required param(s): {', '.join(missing)}", event)

    audience = params.get("audience", "general")
    docs = params["documentUris"]
    md = [
        "# Executive Summary (STUB)",
        f"**Audience:** {audience}",
        "## Highlights",
        "- (stub) Key findings from documents.",
        "## Risks",
        "- (stub) Identified risk 1",
        "## Next Steps",
        "- (stub) Proposed action 1",
        "",
        "### Sources",
    ] + [f"- {u}" for u in docs]

    return ok({"summaryMarkdown": "\n".join(md)}, event)
