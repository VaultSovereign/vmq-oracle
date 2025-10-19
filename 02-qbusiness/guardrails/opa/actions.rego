package vaultmesh.actions

# Expected input contract:
# {
#   "action": "summarize-docs",
#   "user": {
#     "group": "VaultMesh-Engineering",
#     "id": "alice@vaultmesh.io"
#   },
#   "context": {
#     "request_id": "...",
#     "persona": "engineer"
#   }
# }

default allow = false
default approval_required = false
default deny_reason = ""

# Green-tier actions are read-only or draft-generating flows that may execute automatically.
green_actions := {
  "summarize-docs": {"groups": {"VaultMesh-Engineering", "VaultMesh-Delivery", "VaultMesh-Compliance"}},
  "generate-faq": {"groups": {"VaultMesh-Engineering", "VaultMesh-Delivery"}},
  "draft-change-note": {"groups": {"VaultMesh-Engineering", "VaultMesh-Delivery", "VaultMesh-Management"}},
  "validate-schema": {"groups": {"VaultMesh-Engineering"}},
  "create-jira-draft": {"groups": {"VaultMesh-Delivery", "VaultMesh-Engineering"}},
  "compliance-pack": {"groups": {"VaultMesh-Compliance", "VaultMesh-Management"}}
}

# Yellow-tier actions (not yet enabled) may set this set to true.
yellow_actions := {}

# Red-tier actions are blocked entirely until policy owners approve.
red_actions := {}

allow {
  action := input.action
  action_policy := green_actions[action]
  input.user.group in action_policy.groups
}

approval_required {
  action := input.action
  yellow_actions[action]
}

deny_reason := sprintf("action %s is not enabled for group %s", [input.action, input.user.group]) {
  not allow
  not approval_required
}
