import time
from common.vmq_common import authorize_action, ok, err, require

def handler(event, _ctx):
    event["_start_time"] = time.time()
    allowed, approval, deny = authorize_action(event)
    if not allowed and not approval:
        return err(403, deny, event)

    params, _ = require(event, "folderPrefix")
    maxq = int(params.get("maxQuestions", 12))
    prefix = params.get("folderPrefix", "s3://vaultmesh-knowledge-base/docs/")
    faq = [
        "# FAQ (STUB)",
        f"_Derived from folder: **{prefix}**_",
        "",
        "## Q: What does this folder contain?",
        "- Draft answer: curated scrolls for the knowledge base.",
        "## Q: Who owns this content?",
        "- Draft answer: Knowledge Ops.",
        "## Q: How often is it synced?",
        "- Draft answer: On merge to main via CI.",
    ]
    return ok({"faqMarkdown": "\n".join(faq[: (2*maxq) ])}, event)
