Quick Suite Evaluation Checklist (VaultMesh)

Use this checklist to evaluate and plan migration/coexistence from Amazon Q Business to Amazon Quick Suite in eu-west-1. Mark items, assign owners, capture decisions, and define exit criteria per section.

- [ ] Scope locked and stakeholders identified
  - Owner: ____  Due: ____  Decision meeting: ____
  - Success criteria: ____

1) Prerequisites
- [ ] AWS accounts, org, and regions confirmed (primary eu-west-1)
- [ ] Baseline guardrails, KMS, CloudTrail, CloudWatch enabled in the target account(s)
- [ ] SSO (IAM Identity Center) configured and test principal available
- [ ] Data classification policy and PII/PHI handling guidelines accessible

2) Data Residency & Compliance
- [ ] Data processed and stored in EU region(s) (eu-west-1) only
- [ ] Data transfer restrictions reviewed; no cross-geo processing without exemption
- [ ] DPIA/TRA updated for Quick Suite usage
- [ ] DPA/terms reviewed by Legal and Procurement
- [ ] Retention/deletion requirements defined and mapped to product capabilities

3) Identity & Access
- [ ] Identity Provider integrated (IAM Identity Center or external IdP)
- [ ] Group mapping replicated (Engineering, Sales, Management)
- [ ] Spaces/permissions model defined (readers, editors, admins)
- [ ] Admin break-glass and least-privilege roles documented
- [ ] SCIM or group sync path validated (if applicable)

4) Connectors & Content Inventory
- [ ] Required connectors available or roadmap acknowledged (S3, Confluence, GitHub, Google Drive, Slack, Jira, Web Crawler)
- [ ] Access scopes and auth flows defined (OAuth/app, PAT, service principals)
- [ ] Source content inventory and volume estimates completed
- [ ] Sync frequency and windows planned; backfill strategy defined
- [ ] Permissions/ACL propagation strategy confirmed (inherit from source vs. flattened)
- [ ] Blocklist/allowlist, file types, size limits defined
- [ ] Network/VPC, egress, and proxy requirements assessed (if needed)
- [ ] KMS key usage and secrets storage strategy defined

Connector Evaluation Block (duplicate per source)
- [ ] Source: ______  Environment: Dev | Prod
- [ ] Connector type: ______  Auth: OAuth | Token | Role
- [ ] Scopes/permissions: ______
- [ ] Content size (#docs, GB): ______  Expected growth: ______
- [ ] Sync schedule: ______  Backfill plan: ______
- [ ] Permission model: Inherit | Space-level | Public subset
- [ ] PII/PHI presence: Yes | No  Handling notes: ______
- [ ] Network/VPC needs: Yes | No  Details: ______
- [ ] KMS/Secrets: Key ID(s): ______  Secret ARNs: ______
- [ ] Test dataset defined and approved
- [ ] Exit criteria met (search relevance, coverage, errors < threshold)
  - Owner: ____  Due: ____  Status: Planned | In Progress | Done

5) Guardrails & Safety
- [ ] Blocked phrases/keywords defined and applied
- [ ] Topic controls defined (sensitive topics, roles/groups)
- [ ] System message/response policy configured (credentials, personal data)
- [ ] Citation/grounding policy reviewed (require citations for internal content)
- [ ] Data leakage prevention posture confirmed (file types, domains)
- [ ] Abuse monitoring, rate limits, and escalation paths documented

6) Feature & UX Parity
- [ ] Web experience vs. Spaces parity assessed (navigation, sharing, embedding)
- [ ] Q Apps vs. Flows/Automate mapping defined for core use cases
- [ ] Research/answers behavior validated (cited responses, internal + web sources policy)
- [ ] File upload, chat history, and sharing settings verified
- [ ] Accessibility and localization requirements validated

7) Performance & Quality
- [ ] Ground-truth evaluation set created (N queries × K answers per domain)
- [ ] Relevance metrics: target thresholds set (e.g., NDCG@5 ≥ __, HitRate@3 ≥ __)
- [ ] Safety metrics: blocked responses rate ≤ __%; false block ≤ __%
- [ ] Latency SLO: p50 ≤ __s, p95 ≤ __s under expected load
- [ ] Human review protocol defined; sign-off owners assigned

8) Cost & Licensing
- [ ] User tiers selected: Professional ($20/user/mo) | Enterprise ($40/user/mo)
- [ ] User counts by group: Eng __, Sales __, Mgmt __, Partners __
- [ ] Estimated monthly cost = Σ(users × tier price)
- [ ] Connector/usage-based costs reviewed (if any)
- [ ] Budget owner approved and PO in place

9) Observability & Governance
- [ ] Logs/metrics enabled; dashboards for usage, errors, sync health
- [ ] Audit trails for admin and data access events retained ≥ __ days
- [ ] Alerting thresholds established; on-call rotation assigned
- [ ] Change management: versioning, approvals, and rollback documented

10) Operations & Quotas
- [ ] Product and API quotas reviewed; expected headroom ≥ __%
- [ ] Runbooks for common failures (auth expiry, throttling, sync errors)
- [ ] Backup/export strategy for configurations and prompts
- [ ] DR/BCP assumptions documented; RTO/RPO targets defined (if applicable)

11) Migration/Coexistence Plan
- [ ] Phase 0: Read-only pilot in Quick Suite; no user impact
- [ ] Phase 1: Mirror connectors (subset); evaluate parity metrics
- [ ] Phase 2: Expand coverage; enable Spaces for pilot groups
- [ ] Phase 3: Cutover or dual-run decision based on metrics
- [ ] Communication plan and training for impacted users

12) Rollback Plan
- [ ] Triggers defined (quality, latency, incidents, cost overrun)
- [ ] Steps to revert to Q Business configuration and connectors
- [ ] Data/indices cleanup plan and access revocation

13) Security Review
- [ ] IAM policies least-privilege; PassRole constraints applied
- [ ] KMS keys scope reviewed; grants and key rotation policy
- [ ] Secrets lifecycle and rotation
- [ ] Third-party app reviews for connectors (permissions, scopes)

14) Legal & Procurement
- [ ] Terms/DPA reviewed; residency and subprocessors verified
- [ ] Records of processing updated; risk accepted by owners
- [ ] Procurement approved; renewal/cancellation terms tracked

15) Decision & Sign-off
- [ ] Outcome: Proceed | Proceed with mitigations | Defer
- [ ] Effective date: ______  Review date: ______
- [ ] Approvers: Security __, Data __, Product __, Finance __, Exec __

Decision Log (append entries)
- Date: ____  Topic: ____  Decision: ____  Rationale: ____  Owner: ____

Risks & Mitigations (append entries)
- Risk: ____  Impact: Low|Med|High  Likelihood: Low|Med|High  Mitigation: ____  Owner: ____

Notes
- Keep S3/Confluence/GitHub sources and guardrail taxonomy stable to ease coexistence.
- Validate connector schemas and permissions against the latest AWS documentation before production.
