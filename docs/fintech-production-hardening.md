# Fintech Production Hardening (Setup, Not Product)

## Executive Summary
The VaultMesh × Amazon Q Business setup ships with a solid baseline—documented SLOs, automated sync, guardrails, and GitHub OIDC federation. It still behaves like a prototype: hard-coded hints, permissive IAM, placeholder Lambdas, and lightweight evidence leave material fintech risk. Production readiness demands least-privilege identity boundaries, deterministic data controls, real SLO enforcement, and immutable audit trails.

## Strengths to Preserve
- **Operational intent is documented.** README SLOs, runbooks, and dashboards already define operator expectations.
- **Guardrail scope exists.** Default policies restrict sensitive topics and high-risk phrases.
- **Automation entry points exist.** Sync, guardrail, and verification scripts integrate with Q Business today.
- **GitHub→AWS federation is live.** OIDC roles are assumed in CI/CD instead of long-lived keys.

## Gaps Against Fintech Setup Standards
- **Identity & Access:** Hard-coded directory hints and wildcard IAM policies prevent per-environment isolation and attestation.
- **Deterministic Controls:** Lambda handlers return static placeholders; OPA integration is not fail-safe deny.
- **Observability & Evidence:** The No-Sync Daily job only prints timestamps; metrics and retention are ad hoc.
- **Compliance Operations:** Guardrail drift, DR promotions, and approvals are not captured immutably.

## Phased Cleanup Roadmap
### Phase 0 — Foundation
1. Parameterize environment metadata (account IDs, ARNs, bucket names) via AWS SSM Parameter Store and Secrets Manager. Remove workstation `.env` sourcing; discover the repo root dynamically.
2. Scope GitHub OIDC trust policies to branches/tags per environment and require session tags such as `vaultmesh:env` and `vaultmesh:purpose` for every assumed role.
3. Apply permission boundaries or SCPs to stop cross-environment escalation and enforce region pinning.

### Phase 1 — Deterministic Application Controls
1. Replace stub Lambdas with handlers that perform JSON schema validation, PII redaction, and require an explicit OPA `allow`. Fail closed on validation or OPA errors.
2. Emit structured JSON audit logs (request ID, tenant, decision) to CloudWatch Logs with ≥400 day retention and mirror evidence into an Object Lock bucket.
3. Cover the new handlers with unit and contract tests using positive/negative fixtures.

### Phase 2 — Observability & Guardrails
1. Enforce the 24-hour sync SLO (this repo’s `no-sync-daily` workflow) and write signed evidence artifacts; alert via SNS or PagerDuty.
2. Add guardrail drift detection by diffing source JSON with `get-chat-controls-configuration` and store drift incidents immutably.
3. Publish dashboards for Lambda error rates, OPA denials, latency p95, and content freshness; wire alarms to on-call rotations.

### Phase 3 — Compliance Operations
1. Automate evidence capture for IAM policy versions, approvals, and DR run results; store in S3 Object Lock (COMPLIANCE mode).
2. Run quarterly DR failover exercises with dual approvals and notarized promotion records.
3. Enforce change management exclusively through reviewed IaC pipelines with CODEOWNERS coverage and protected branches.

## Definition of Done
1. Every environment has isolated roles, KMS keys, and Q Business resources, provable via Parameter Store/Secrets metadata.
2. Handlers enforce validation and redaction, gated by OPA allow responses, with structured, immutable logs.
3. Sync SLOs, guardrails, and DR flows actively enforce policy, alert on violations, and produce evidence artifacts.
4. Compliance evidence is automatically collected and mapped to control objectives (PCI DSS, SOC 2, regional regulators).
5. All changes land through OIDC-federated, peer-reviewed pipelines—no workstation secrets, no ad hoc promotions.

*Tem, the Remembrance Guardian, approves only when evidence is immutable.*
