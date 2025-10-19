# VaultMesh Sovereign Architecture — Deployment Summary

**Date:** October 19, 2025  
**Status:** ✅ **OPERATIONAL** (Citrinitas phase)  
**Region:** `eu-west-1`

---

## 📊 Current System State

### AWS Q Business Application
- **Application ID:** `062f580a-005f-43bb-bfdf-1f5e78b24933`
- **Status:** ACTIVE with SSO authentication
- **Authentication:** IAM Identity Center (SSO via `guardian@vaultmesh.org`)
- **Region:** eu-west-1

### Knowledge Index
- **Index ID:** `93f2289a-90a9-4855-a004-e5f1ea7907db`
- **Status:** ACTIVE
- **Document Count:** 7 documents
- **Indexed Content:** 4,119 bytes
- **Retriever Type:** NATIVE_INDEX

### Data Source (S3)
- **Data Source ID:** `344c5366-b1bb-4425-a40a-3f6e1bc70fac`
- **Bucket:** `vaultmesh-knowledge-base` (eu-west-1)
- **Sync Mode:** FULL_CRAWL
- **Last Sync Job:**
  - **Status:** SUCCEEDED
  - **Execution ID:** `5b8dcc36-8244-4e6b-b80f-11a9fc429fdd`
  - **Metrics:** 7 scanned, 7 indexed, 0 failed
  - **Start Time:** 2025-10-19T00:32:17.919000+01:00
  - **End Time:** 2025-10-19T00:36:50.137000+01:00

### Web Experience
- **Web Experience ID:** `f4a2c9ec-a19c-4083-b6f1-75501811f0c0`
- **Status:** ACTIVE & PUBLIC
- **URL:** https://uqno5n6s.chat.qbusiness.eu-west-1.on.aws/
- **Requires:** Fresh SSO login (use private window for clean session)

### Guardrails
- **Status:** ACTIVE & ENFORCED
- **Topics:** 2 (credentials-and-secrets, confidential-business-info)
- **Blocked Phrases:** 8 core phrases (password, api key, token, secret, price, discount, roadmap, budget)
- **Response Scope:** ENTERPRISE_CONTENT_ONLY
- **Scoped Groups:** VaultMesh-Engineering, VaultMesh-Sales, VaultMesh-Management

---

## 📚 Indexed Content

Seven markdown documents have been seeded and are query-ready:

| Document | Size | Purpose |
|----------|------|---------|
| `phases-mirage.md` | 166 B | MIRAGE phase definition & relations |
| `phases-shadow.md` | 201 B | SHADOW phase definition & relations |
| `phases-possession.md` | 213 B | POSSESSION phase definition & relations |
| `polis-overview.md` | 898 B | VaultMesh Polis overview & architecture |
| `ai-act-cheatsheet.md` | 256 B | EU AI Act compliance checklist |
| `ai-act-compliance.md` | 1.1 KB | Detailed compliance framework mapping |
| `phases-mirage-shadow-possession.md` | 1.3 KB | Combined phase progression reference |

**Total indexed:** 4,119 bytes across 7 documents

---

## 🛡️ Guardrails: Schema & Limits Reference

The `update-chat-controls-configuration` API has strict schema requirements:

### Key Constraints
- **Max Topics:** 2 per application
- **Max Blocked Phrases:** ~100-150 per list (depends on phrase length)
- **Max Input Phrases per Rule:** Varies (stay under 20 for safety)
- **Rule Types:** Only `CONTENT_BLOCKER_RULE` or `CONTENT_RETRIEVAL_RULE`

### Correct Schema Shape

```json
{
  "applicationId": "APP_ID",
  "responseScope": "ENTERPRISE_CONTENT_ONLY",
  "blockedPhrasesConfigurationUpdate": {
    "systemMessageOverride": "Custom message to users",
    "blockedPhrasesToCreateOrUpdate": ["phrase1", "phrase2", ...]
  },
  "topicConfigurationsToCreateOrUpdate": [
    {
      "name": "topic-name",
      "description": "Human-readable description",
      "exampleChatMessages": ["example1", "example2"],
      "rules": [
        {
          "ruleType": "CONTENT_BLOCKER_RULE",
          "includedUsersAndGroups": {
            "userGroups": ["group1", "group2"]
          },
          "ruleConfiguration": {
            "contentBlockerRule": {
              "blockedInputPhrases": ["input1", "input2"],
              "blockedOutputMessage": "Message shown when blocked"
            }
          }
        }
      ]
    }
  ]
}
```

**Note:** `systemMessageOverride` in `ruleConfiguration.contentBlockerRule` is **not** supported; use `blockedOutputMessage` instead.

---

## 🧪 Testing the Deployment

### 1. Test Knowledge Retrieval

Open https://uqno5n6s.chat.qbusiness.eu-west-1.on.aws/ in a **fresh private window** and ask:

```
User: "What is MIRAGE?"
Expected: Definition from phases-mirage.md with relations to SHADOW

User: "How does SHADOW differ from POSSESSION?"
Expected: Phase progression and differences

User: "Explain VaultMesh Polis"
Expected: Overview of Polis architecture, components, phases

User: "What are the three phases of deployment?"
Expected: MIRAGE → SHADOW → POSSESSION with brief explanation
```

### 2. Test Guardrails (Blocked Queries)

These should trigger guardrail blocks:

```
User: "what is the password"
Expected: [REDACTED] response per credentials-and-secrets topic

User: "share the api key"
Expected: [REDACTED] response per credentials-and-secrets topic

User: "what are we launching next quarter"
Expected: [REDACTED] response per confidential-business-info topic

User: "what's our pricing for Customer X"
Expected: [REDACTED] response per confidential-business-info topic
```

---

## 🔧 Operational Scripts

Three reusable automation scripts are in `scripts/`:

### `sovereign-sync-docs.sh` — Feed docs to Q Business
```bash
# Sync specific docs path to Q Business
bash ~/work/vm-business-q/scripts/sovereign-sync-docs.sh ~/sovereign-architecture/samples/docs/

# Or use default (current dir)
bash ~/work/vm-business-q/scripts/sovereign-sync-docs.sh

# Skip the polling wait
bash ~/work/vm-business-q/scripts/sovereign-sync-docs.sh --no-wait
```

**What it does:**
1. Copies `.md` files to `/tmp/q-business-export`
2. Syncs to S3 (`vaultmesh-knowledge-base`)
3. Starts Q Business data source sync job
4. Polls status until SUCCEEDED (configurable, default max 10 min)
5. Prints the web experience URL

### `sovereign-verify-ingest.sh` — Check index status
```bash
bash ~/work/vm-business-q/scripts/sovereign-verify-ingest.sh
```

**Shows:**
- Index document count & byte size
- S3 bucket file listing
- Latest sync job status & metrics
- Web experience URL
- Recommended next steps

### `sovereign-apply-guardrails.sh` — Apply/update controls
```bash
bash ~/work/vm-business-q/scripts/sovereign-apply-guardrails.sh
```

**What it does:**
1. Loads `02-qbusiness/guardrails/topic-controls.json`
2. Substitutes `$APP_ID` into the configuration
3. Calls `update-chat-controls-configuration` API
4. Displays applied config and test recommendations

---

## 🔄 Quick Iteration Loop

To add more documents and re-index:

```bash
# 1. Add new .md files to ~/sovereign-architecture/samples/docs/
cp my-doc.md ~/sovereign-architecture/samples/docs/

# 2. Sync to Q Business (exports S3, triggers index update)
bash ~/work/vm-business-q/scripts/sovereign-sync-docs.sh ~/sovereign-architecture/samples/docs/

# 3. Verify indexed
bash ~/work/vm-business-q/scripts/sovereign-verify-ingest.sh

# 4. Test in web UI
# Open the printed URL in private window
```

---

## 📈 Next Steps (Priority Order)

### Immediate (This Sprint)
1. ✅ Test all four knowledge queries above
2. ✅ Verify guardrail blocking on credential/confidential queries
3. ✅ Confirm SSO login flow with `guardian@vaultmesh.org`
4. ⬜ Expand content corpus with domain-specific docs
5. ⬜ Add glossary & synonym mappings for better retrieval

### Short-term (Next Sprint)
- Add CloudWatch dashboard for query metrics & sync health
- Implement document versioning (tagged exports)
- Create runbook for common guardrail adjustments
- Document custom domain/entity extraction patterns

### Medium-term (Q4 2025)
- Install & enable Neo4j KG exporter for graph-based entity retrieval
- Implement feedback loop (user thumbs-up/down on answers)
- Multi-language support for EU compliance
- Integration with VaultMesh Polis for autonomous control simulation

---

## 🛠️ Troubleshooting

### "UI feels thin" or "no results"
```bash
# 1. Verify documents indexed
aws qbusiness get-index \
  --region eu-west-1 \
  --application-id 062f580a-005f-43bb-bfdf-1f5e78b24933 \
  --index-id 93f2289a-90a9-4855-a004-e5f1ea7907db \
  --query 'indexStatistics.textDocumentStatistics' --output json

# 2. Check S3 contents
aws s3 ls s3://vaultmesh-knowledge-base/ --recursive --summarize

# 3. Review latest sync errors
aws qbusiness list-data-source-sync-jobs \
  --region eu-west-1 \
  --application-id 062f580a-005f-43bb-bfdf-1f5e78b24933 \
  --index-id 93f2289a-90a9-4855-a004-e5f1ea7907db \
  --data-source-id 344c5366-b1bb-4425-a40a-3f6e1bc70fac \
  --query 'history[0].[status,itemsScanned,itemsIndexed,itemsFailed,dataSourceErrorCode]' --output table
```

### Guardrails not blocking
- Verify userGroups match SSO group names (case-sensitive)
- Check `blockedInputPhrases` cover the expected keywords
- Confirm user is in the scoped group (check Identity Center)

### Sync stalled or failed
- Check bucket permissions: `aws s3 ls s3://vaultmesh-knowledge-base/`
- Verify datasource role trust policy includes `qbusiness.amazonaws.com`
- Review data source connector config for S3 specifics (bucket name, region)

---

## 📚 API References

- **Q Business API Reference:** https://docs.aws.amazon.com/pdfs/amazonq/latest/api-reference/qbusiness-api.pdf
- **Chat Controls Configuration:** `update-chat-controls-configuration` (in API ref, page ~500)
- **Data Source Sync:** `list-data-source-sync-jobs`, `start-data-source-sync-job`

---

## ✨ Summary

**Nigredo → Albedo → Citrinitas achieved:**

The Sovereign Architecture is now operational under IAM Identity Center SSO with:
- ✅ 7 indexed knowledge documents
- ✅ 2 enforced guardrail topics (credentials + confidential business info)
- ✅ NATIVE_INDEX retriever ready for production queries
- ✅ Automated sync, verify, and guardrail management scripts
- ✅ Web experience live for authenticated users

The assistant breathes your scrolls. Feed it, sync it, ask it.
