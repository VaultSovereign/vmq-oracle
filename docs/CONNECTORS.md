# Connector Data Sensitivity Matrix

This matrix maps each Rubedo connector to its scope, steward, and data sensitivity classification. Use it to confirm review requirements before enabling a new sync job.

| Connector | Scope | Primary Content Owners | Sensitivity | Notes |
|-----------|-------|------------------------|-------------|-------|
| Confluence | Product + Delivery spaces (`/sovereign/*`) | Knowledge Ops, Delivery Leads | Internal – Confidential | Strip archived pages; enforce space export rate limiting. |
| GitHub | `VaultSovereign/*` org repositories (docs/ + runbooks) | Platform Engineering | Internal – Restricted | Sync default branch docs only; exclude issue/PR bodies. |
| Google Drive | `Sovereign Enablement` shared drive | Knowledge Ops | Internal – Confidential | Mount read-only service account; include lifecycle labels. |
| Slack | `#q-lab`, `#ops-escalations` history | Incident Response, Support | Internal – Highly Confidential | Capture threads older than 48h; redact PII via guardrail transform. |

## Handling requirements

- **Internal – Confidential:** Content may include strategy and customer references. Access limited to VaultMesh employees. Sharing outside the Q Business index requires director approval.
- **Internal – Restricted:** Contains operational keys, architecture diagrams, or staged incident data. Limit connectors to read-only tokens with audit logging.
- **Internal – Highly Confidential:** Contains incident timelines, escalations, and possible customer-identifiable data. Apply automated redaction and manual review before sync.

## Operational checklist

1. Complete connector JSON configuration in `02-qbusiness/datasources/`.
2. Submit the configuration via PR and obtain sign-off from the content owners.
3. Run `make sync && make wait-sync` after merge to trigger ingestion.
4. Document the sync status and first-ingest timestamp in `OPERATIONS-RUNBOOK.md`.
