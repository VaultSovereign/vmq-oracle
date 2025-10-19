import json, os, time, logging, urllib.request
try:
    import boto3
    CW = boto3.client("cloudwatch")
except Exception:
    CW = None

LOG = logging.getLogger()
if not LOG.handlers:
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
LOG.setLevel(os.getenv("LOG_LEVEL", "INFO"))

OPA_URL = os.getenv("OPA_URL")
ALLOW_QUERY = "allow"
DENY_QUERY  = "deny_reason"
APPROVAL_QUERY = "approval_required"

_GREEN = {
    "summarize-docs":    {"groups": {"VaultMesh-Engineering","VaultMesh-Delivery","VaultMesh-Compliance"}},
    "generate-faq":      {"groups": {"VaultMesh-Engineering","VaultMesh-Delivery"}},
    "draft-change-note": {"groups": {"VaultMesh-Engineering","VaultMesh-Delivery","VaultMesh-Management"}},
    "validate-schema":   {"groups": {"VaultMesh-Engineering"}},
    "create-jira-draft": {"groups": {"VaultMesh-Delivery","VaultMesh-Engineering"}},
    "compliance-pack":   {"groups": {"VaultMesh-Compliance","VaultMesh-Management"}},
}

def _json(o): return json.dumps(o, separators=(",", ":"), ensure_ascii=False)

def _call_opa(path_suffix, payload):
    if not OPA_URL:
        raise RuntimeError("OPA_URL not set")
    req = urllib.request.Request(
        f"{OPA_URL}/{path_suffix}",
        data=_json({"input": payload}).encode("utf-8"),
        headers={"Content-Type":"application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=2.5) as r:
        return json.loads(r.read().decode("utf-8")).get("result")

def authorize_action(evt):
    if OPA_URL:
        try:
            allowed = bool(_call_opa(ALLOW_QUERY, evt))
            approval = bool(_call_opa(APPROVAL_QUERY, evt))
            deny = "" if allowed or approval else (_call_opa(DENY_QUERY, evt) or "denied by policy")
            return allowed, approval, deny
        except Exception as e:
            LOG.warning("OPA unreachable, falling back to static green map: %s", e)

    action = evt.get("action")
    group  = (evt.get("user") or {}).get("group")
    g = _GREEN.get(action)
    if g and group in g["groups"]:
        return True, False, ""
    return False, False, f"action {action} is not enabled for group {group}"

def ok(body: dict, evt: dict) -> dict:
    rid = ((evt.get("context") or {}).get("request_id")) or str(int(time.time()*1000))
    action = evt.get("action", "unknown")
    start = evt.get("_start_time", time.time())
    latency_ms = (time.time() - start) * 1000
    LOG.info(_json({"event":"action_ok","action":action,"request_id":rid,"user":evt.get("user"),"latency_ms":latency_ms}))

    # Publish CloudWatch metrics
    if CW:
        try:
            CW.put_metric_data(
                Namespace="VaultMesh/QBusinessActions",
                MetricData=[
                    {"MetricName": "ActionsInvoked", "Value": 1.0, "Unit": "Count", "Dimensions": [{"Name": "ActionId", "Value": action}]},
                    {"MetricName": "ActionLatency", "Value": latency_ms, "Unit": "Milliseconds", "Dimensions": [{"Name": "ActionId", "Value": action}]},
                ]
            )
        except Exception as e:
            LOG.warning(f"Failed to publish metric: {e}")

    return {"statusCode": 200, "headers":{"Content-Type":"application/json"}, "body": json.dumps(body)}

def err(status: int, msg: str, evt: dict) -> dict:
    LOG.warning(_json({"event":"action_err","status":status,"reason":msg,"action":evt.get("action"),"user":evt.get("user")}))
    return {"statusCode": status, "headers":{"Content-Type":"application/json"}, "body": json.dumps({"error": msg})}

def require(evt: dict, *keys):
    params = evt.get("params") or {}
    missing = [k for k in keys if k not in params or params[k] in (None, "")]
    return params, missing
