# RUBEDO Deployment - Quick Start

**Status:** ✅ **DEPLOYED & READY**
**Date:** 2025-10-19
**Version:** 1.0.0-rubedo

---

## 🎯 What Is This?

**RUBEDO** is VaultMesh's guarded agency system for AWS Q Business. It provides:

- **6 GREEN-tier actions** (Lambda-based, policy-gated)
- **3 role-aware personas** (engineer, delivery-manager, compliance)
- **Complete UI integration** (React components + API routes)
- **Production observability** (CloudWatch metrics + structured logs)

**Philosophy:** Substrate (AWS) + Civilization (VaultMesh) = Convergence

---

## 🚀 Quick Deploy (48 Hours)

### Day 1: Frontend Integration (90 min)

```bash
# 1. Extract package
tar -xzf rubedo-ui-integration.tar.gz

# 2. Install dependencies
npm install @aws-sdk/client-s3 @aws-sdk/client-lambda

# 3. Copy files to your app
cp -r 04-ui-integration/lib src/
cp -r 04-ui-integration/api src/app/api/actions/
cp 04-ui-integration/components/ActionHandoff.tsx src/components/

# 4. Configure
cp 04-ui-integration/config/env.template .env.local
# Edit .env.local with AWS_REGION, AWS_S3_BUCKET, etc.

# 5. Add to chat UI
import ActionHandoff from "@/components/ActionHandoff";
<ActionHandoff selectedUris={docs} user={user} />

# 6. Test locally
npm run dev
./04-ui-integration/scripts/action-invoke.sh summarize-docs \
  alice@vaultmesh.io VaultMesh-Engineering \
  '{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"]}'
```

### Day 2: SSO Enablement (2.5 hours)

See [DEPLOYMENT-HANDOFF.md](DEPLOYMENT-HANDOFF.md) for complete steps.

---

## 📚 Documentation Map

Start here based on your role:

### For Frontend Developers
1. **[04-ui-integration/README.md](04-ui-integration/README.md)** - Complete integration guide
2. **[04-ui-integration/INTEGRATION-CHECKLIST.md](04-ui-integration/INTEGRATION-CHECKLIST.md)** - Step-by-step deployment

### For DevOps/Infrastructure
1. **[DEPLOYMENT-HANDOFF.md](DEPLOYMENT-HANDOFF.md)** - Deployment procedures
2. **[RUBEDO-DEPLOYMENT-SUMMARY.md](RUBEDO-DEPLOYMENT-SUMMARY.md)** - Infrastructure overview
3. **[02-qbusiness/actions/ROLLOUT-GUIDE.md](02-qbusiness/actions/ROLLOUT-GUIDE.md)** - Ops runbook

### For Product/Leadership
1. **[UI-INTEGRATION-COMPLETE.md](UI-INTEGRATION-COMPLETE.md)** - Executive summary
2. **[02-qbusiness/actions/RUBEDO-INTEGRATION.md](02-qbusiness/actions/RUBEDO-INTEGRATION.md)** - Technical deep dive

---

## ✅ Current Status

### Infrastructure (All Deployed ✓)
- **6 Lambda Functions:** vmq-actions-rubedo stack
- **Actions Catalog:** s3://vaultmesh-knowledge-base/actions/catalog.json
- **3 Personas:** s3://vaultmesh-knowledge-base/personas/
- **Guardrails:** Anonymous mode (blocked phrases)
- **Dashboard:** VaultMesh-Sovereign with Actions widgets
- **Validation:** All checks passing

### UI Integration Package (Ready ✓)
- **Package:** rubedo-ui-integration.tar.gz (16 KB)
- **Code:** 1,736 lines of production-ready TypeScript/React
- **Documentation:** 476 lines of integration guides
- **Tests:** CLI harness + smoke tests

---

## 🔍 Validation

Run full system check:
```bash
./scripts/rubedo-validate.sh
```

Expected output:
```
✓ All 6 Lambda functions deployed
✓ S3 assets published
✓ CloudFormation stack healthy
✓ Q Business app active
✓ Smoke tests passing (200/403)
✓ Dashboard exists
```

---

## 📦 Files Overview

```
vm-business-q/
├── rubedo-ui-integration.tar.gz      # UI package (extract this)
├── DEPLOYMENT-HANDOFF.md              # Start here for deployment
├── UI-INTEGRATION-COMPLETE.md         # Executive summary
├── RUBEDO-DEPLOYMENT-SUMMARY.md       # Infrastructure details
├── 04-ui-integration/                 # Full UI package
│   ├── README.md                      # Integration guide
│   ├── INTEGRATION-CHECKLIST.md       # Go-live checklist
│   ├── lib/                           # Server utilities
│   ├── api/                           # API routes
│   ├── components/                    # React components
│   ├── config/                        # Environment + deps
│   └── scripts/                       # CLI tools
├── 02-qbusiness/actions/              # Backend infrastructure
│   ├── RUBEDO-INTEGRATION.md          # Technical guide
│   ├── ROLLOUT-GUIDE.md               # Ops procedures
│   └── actions-catalog.json           # 6 GREEN actions
├── 03-lambdas/                        # Lambda functions
│   ├── deploy.sh                      # Deployment script
│   ├── persona_helper.py              # Python helper
│   └── [6 Lambda handlers]
└── scripts/
    ├── rubedo-validate.sh             # System validation
    └── final-validation.sh            # End-to-end tests
```

---

## 🎯 Success Metrics

### Week 1 Targets
- Actions invoked: > 50 total
- Error rate: < 1%
- User satisfaction: Positive feedback

### Month 1 Targets
- Daily actions: > 10/day
- All 6 actions used
- All 3 personas active

---

## 🔗 Quick Links

**Dashboard:**
https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=VaultMesh-Sovereign

**Catalog:**
s3://vaultmesh-knowledge-base/actions/catalog.json

**Personas:**
s3://vaultmesh-knowledge-base/personas/

**Logs:**
/aws/lambda/vmq-*

---

## 🛡️ Emergency Procedures

### Disable All Actions (< 1 min)
```bash
aws s3 cp s3://vaultmesh-knowledge-base/actions/catalog.json /tmp/
jq '.catalog[].enabled = false' /tmp/catalog.json > /tmp/disabled.json
aws s3 cp /tmp/disabled.json s3://vaultmesh-knowledge-base/actions/catalog.json --cache-control "no-cache"
```

### Full Rollback
See [DEPLOYMENT-HANDOFF.md#rollback-procedures](DEPLOYMENT-HANDOFF.md)

---

## 📞 Support

**Documentation Questions:** See docs map above
**Deployment Issues:** #vaultmesh-ops (Slack)
**Incidents:** PagerDuty on-call
**Runbooks:** RUNBOOK-IR.md, RUNBOOK-DR.md

---

## 🧭 Evolutionary Path

**RUBEDO (2025 Q4)** → Guarded agency ✓ Complete
**FUSION (2026)** → Autonomous collaboration (memory + metering)
**SOVEREIGN (2028)** → Federated intelligence (Q↔Q federation)
**CONVERGENCE (2030+)** → Universal cognition commons

---

## ✨ The Philosophy

> *Solve et Coagula* — Dissolve the silos, coagulate the intelligence.

AWS built the **substrate** (Q Business, Lambda, S3).
VaultMesh built the **civilization** (personas, policies, provenance).
Together they form one **coherent system** for organizational intelligence.

RUBEDO is the awakening of agency within the substrate.
The key is turned. The civilization breathes.

---

**Ready to deploy?** Start with [DEPLOYMENT-HANDOFF.md](DEPLOYMENT-HANDOFF.md)

**Questions?** Read [04-ui-integration/README.md](04-ui-integration/README.md)

**Let's ship.** 🚀
