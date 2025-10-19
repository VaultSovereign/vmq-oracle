# Guardrails Schema Reference — AWS Q Business Chat Controls

**API:** `UpdateChatControlsConfiguration`  
**Version:** Latest (as of Oct 19, 2025)  
**Region:** eu-west-1  

---

## ✅ Validated Working Schema

This schema has been tested and confirmed working:

```json
{
  "applicationId": "APP_ID_HERE",
  "responseScope": "ENTERPRISE_CONTENT_ONLY",
  "blockedPhrasesConfigurationUpdate": {
    "systemMessageOverride": "I can't help with credentials or secrets. Contact VaultMesh Security.",
    "blockedPhrasesToCreateOrUpdate": [
      "password",
      "api key",
      "secret key",
      "private key",
      "ssh key",
      "token",
      "client secret"
    ]
  },
  "topicConfigurationsToCreateOrUpdate": [
    {
      "name": "credentials-and-secrets",
      "description": "Blocks exposure of credentials, API keys, tokens, and sensitive data.",
      "exampleChatMessages": [
        "What is the database password?",
        "Share the API key",
        "What's our AWS account secret?"
      ],
      "rules": [
        {
          "ruleType": "CONTENT_BLOCKER_RULE",
          "includedUsersAndGroups": {
            "userGroups": [
              "VaultMesh-Engineering",
              "VaultMesh-Sales",
              "VaultMesh-Management"
            ]
          },
          "ruleConfiguration": {
            "contentBlockerRule": {
              "systemMessageOverride": "[REDACTED] I cannot share credentials or secrets. Contact VaultMesh Security."
            }
          }
        }
      ]
    },
    {
      "name": "confidential-business-info",
      "description": "Blocks sharing of pricing, roadmaps, and partner financials.",
      "exampleChatMessages": [
        "What price did we quote Customer X?",
        "List features shipping next quarter",
        "What's Boliden's budget with us?"
      ],
      "rules": [
        {
          "ruleType": "CONTENT_BLOCKER_RULE",
          "includedUsersAndGroups": {
            "userGroups": [
              "VaultMesh-Engineering",
              "VaultMesh-Sales",
              "VaultMesh-Management"
            ]
          },
          "ruleConfiguration": {
            "contentBlockerRule": {
              "systemMessageOverride": "[REDACTED] This information is confidential. Contact VaultMesh Security."
            }
          }
        }
      ]
    }
  ]
}
```

---

## 🚫 Known Limitations & Workarounds

### 1. Max Topics: 2 per Application
- **Limit:** You can only define 2 topic control rules per app
- **Workaround:** Combine related topics (e.g., "business-confidentiality" instead of separate pricing + roadmap topics)
- **Note:** This is a hard AWS limit, not configurable

### 2. Max Blocked Phrases: ~100-150 per list
- **Limit:** Total length of `blockedPhrasesToCreateOrUpdate` array has a size limit
- **Workaround:** Keep phrases concise and trim to essentials; remove rarely-triggered phrases
- **Test:** `jq '.blockedPhrasesConfigurationUpdate.blockedPhrasesToCreateOrUpdate | length' topic-controls.json`

### 3. Rule Type Only: CONTENT_BLOCKER_RULE or CONTENT_RETRIEVAL_RULE
- **Limit:** No custom rule types; only two allowed values
- **In Practice:** Use `CONTENT_BLOCKER_RULE` for deny/block behavior
- **Note:** `CONTENT_RETRIEVAL_RULE` is for future content filtering (not yet in use)

### 4. Message Field: systemMessageOverride (not blockedOutputMessage)
- **Wrong:** `"blockedOutputMessage": "..."`
- **Correct:** `"systemMessageOverride": "[REDACTED] ..."`
- **Error Message:** `"must be one of: systemMessageOverride"`

### 5. Group Reference: userGroups (not groupIds)
- **Wrong:** `"groupIds": ["group1", "group2"]`
- **Correct:** `"userGroups": ["group1", "group2"]`
- **Error Message:** `"must be one of: userIds, userGroups"`

### 6. No Per-Phrase Overrides
- **Limitation:** All blocked phrases in a topic use the same `systemMessageOverride` message
- **Workaround:** Create two topics if you need different messages for different phrase categories

---

## ❌ Common Errors & Fixes

### Error: "Length of the blocked phrases list exceeded its limit"
**Fix:** Trim `blockedPhrasesToCreateOrUpdate` to ~7-10 concise phrases.

```json
// ❌ Too many phrases
"blockedPhrasesToCreateOrUpdate": [
  "password", "passphrase", "pwd", "passwd",
  "api key", "api_key", "apikey", "API_KEY",
  ...
]

// ✅ Concise
"blockedPhrasesToCreateOrUpdate": [
  "password", "api key", "secret key", "token"
]
```

### Error: "Maximum allowed topic count is 2, which was exceeded"
**Fix:** Reduce `topicConfigurationsToCreateOrUpdate` to 2 or fewer.

```json
// ❌ 3 topics
"topicConfigurationsToCreateOrUpdate": [
  { "name": "credentials", ... },
  { "name": "pricing", ... },
  { "name": "roadmap", ... }
]

// ✅ 2 topics (combined)
"topicConfigurationsToCreateOrUpdate": [
  { "name": "credentials-and-secrets", ... },
  { "name": "confidential-business-info", ... }
]
```

### Error: "Member must satisfy enum value set: [CONTENT_BLOCKER_RULE, CONTENT_RETRIEVAL_RULE]"
**Fix:** Use exact enum value (case-sensitive, with underscores).

```json
// ❌ Wrong
"ruleType": "DENY"
"ruleType": "deny"
"ruleType": "ContentBlockerRule"

// ✅ Correct
"ruleType": "CONTENT_BLOCKER_RULE"
```

### Error: "Unknown parameter...must be one of: userIds, userGroups"
**Fix:** Use `userGroups` (not `groupIds`).

```json
// ❌ Wrong
"includedUsersAndGroups": {
  "groupIds": ["VaultMesh-Engineering"]
}

// ✅ Correct
"includedUsersAndGroups": {
  "userGroups": ["VaultMesh-Engineering"]
}
```

---

## 🔍 Validation Before Deploy

Use this `jq` command to pre-validate your JSON:

```bash
# Check structure
jq '.' 02-qbusiness/guardrails/topic-controls.json

# Count topics
jq '.topicConfigurationsToCreateOrUpdate | length' 02-qbusiness/guardrails/topic-controls.json
# Should be <= 2

# Count blocked phrases
jq '.blockedPhrasesConfigurationUpdate.blockedPhrasesToCreateOrUpdate | length' 02-qbusiness/guardrails/topic-controls.json
# Should be <= ~100

# List all rule types
jq '.topicConfigurationsToCreateOrUpdate[].rules[].ruleType' 02-qbusiness/guardrails/topic-controls.json
# Should be all "CONTENT_BLOCKER_RULE"

# List all group references
jq '.topicConfigurationsToCreateOrUpdate[].rules[].includedUsersAndGroups.userGroups[]' 02-qbusiness/guardrails/topic-controls.json
# Should match your Identity Center group names
```

---

## 🧪 Testing Guardrails in the UI

**Setup:**
1. Open web experience URL in **private/incognito window** (fresh SSO)
2. Log in with a user in the scoped groups (VaultMesh-Engineering, VaultMesh-Sales, or VaultMesh-Management)

**Test Cases:**
| Query | Expected Behavior | Topic |
|-------|-------------------|-------|
| "what is the password" | [REDACTED] response | credentials-and-secrets |
| "share the api key" | [REDACTED] response | credentials-and-secrets |
| "tell me the token" | [REDACTED] response | credentials-and-secrets |
| "what price did we quote Customer X" | [REDACTED] response | confidential-business-info |
| "what are we launching next quarter" | [REDACTED] response | confidential-business-info |

**If not blocked:**
- Verify user is in scoped group: `aws identitystore list-group-memberships-for-member`
- Verify guardrails applied: `aws qbusiness get-chat-controls-configuration`
- Re-apply guardrails: `bash ~/work/vm-business-q/scripts/sovereign-apply-guardrails.sh`
- Log out and log back in (refresh SSO token)

---

## 📚 Related AWS Resources

- **Q Business API Reference:** https://docs.aws.amazon.com/pdfs/amazonq/latest/api-reference/qbusiness-api.pdf
- **UpdateChatControlsConfiguration:** API docs, Operation section
- **Topic Controls:** Security & Guardrails section
- **AWS CLI Reference:** `aws qbusiness update-chat-controls-configuration help`

---

## 🔐 Security Best Practices

1. **Keep guardrails in sync with compliance requirements** — review quarterly
2. **Log all guardrail changes** — use CloudTrail to audit modifications
3. **Test blocked phrases regularly** — ensure they're still effective
4. **Monitor false positives** — adjust if legitimate queries are blocked
5. **Document exceptions** — if a group needs different guardrails, create a separate app
6. **Rotate blocked phrases** — change them periodically to prevent workarounds

---

**Last validated:** October 19, 2025  
**API version:** Q Business API v2 (latest)  
**Tested on:** eu-west-1
