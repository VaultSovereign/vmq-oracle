import time
from common.vmq_common import authorize_action, ok, err, require

def handler(event, _ctx):
    event["_start_time"] = time.time()
    allowed, approval, deny = authorize_action(event)
    if not allowed and not approval:
        return err(403, deny, event)

    params, missing = require(event, "baselineUri", "updatedUri")
    if missing:
        return err(400, f"missing required param(s): {', '.join(missing)}", event)

    baseline = params["baselineUri"]
    updated  = params["updatedUri"]
    window   = params.get("changeWindow", "Unspecified")

    md = f"""# Change Note (STUB)
**Window:** {window}

## Summary
- Drafted change note between **{baseline}** and **{updated}**.

## Deltas
- (stub) Added section X
- (stub) Updated requirement Y
- (stub) Removed obsolete Z

## Impact
- (stub) Low / Medium / High

## Reviewers
- (stub) @owner1
- (stub) @owner2
"""
    return ok({"changeMarkdown": md}, event)
