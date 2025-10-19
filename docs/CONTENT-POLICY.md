# Content Policy — VaultMesh Q Business

This policy describes the types of content that may be published into the Q Business index, how long it remains available, and how reviews are conducted. It applies to every connector and manual upload.

## Allowed content

- Product documentation, enablement guides, FAQs, and process playbooks cleared for internal distribution.
- Incident retrospectives that have completed postmortem review and PII scrubbing.
- Customer communications that are contractually shareable within VaultMesh.
- Security policies and governance documents with explicit "Internal" labeling.
- Short-form knowledge scrolls that summarize workflows or troubleshooting steps.

## Prohibited content

- Any material classified above Internal – Highly Confidential (e.g., board minutes, M&A plans).
- Secrets, credentials, or API keys not already redacted by automation.
- Raw customer data exports, billing statements, or PII/PHI without anonymization.
- Legal documents under active negotiation or attorney-client privilege.
- Content breaching partner NDAs or containing embargoed announcements.

## Time to Live (TTL) & lifecycle

| Content class | TTL | Lifecycle actions |
|---------------|-----|-------------------|
| Operational runbooks | 12 months | Review quarterly; retire when superseded. |
| Incident retrospectives | 18 months | Confirm corrective actions completed; archive after TTL. |
| Product docs & FAQs | Continuous | Update with each release; mark stale items with `needs-update`. |
| Training scrolls | 6 months | Replace with updated workflow recordings. |

## Review cadence

1. **Monthly sweep:** Knowledge Ops reviews sync deltas and flags content older than TTL minus 30 days.
2. **Quarterly audit:** Content owners verify classification labels, guardrail coverage, and connector scopes.
3. **Incident spot checks:** Within 72 hours of a Severity 1 incident, IR lead validates Slack and doc captures before indexing.

## Publishing workflow

1. Author updates content in source system with clear metadata (owner, review date, classification).
2. Submit PR or change request referencing this policy.
3. After approval, run the appropriate `make sync` target and monitor `make wait-sync` completion.
4. Record the update in `OPERATIONS-RUNBOOK.md` and include any guardrail changes.

## Exceptions

Any policy exception requires VP Knowledge Ops approval and must be logged in the `OPERATIONS-RUNBOOK.md` change log with rationale, duration, and mitigation steps.
