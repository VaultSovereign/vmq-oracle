# Personas Catalog

The JSON files in this directory define the role-aware prompt templates consumed by the Q Business application during conversation initialization.

## Loading flow

1. The application determines the caller’s primary IAM group from the federated identity context (`VaultMesh-*` groups today).
2. It looks up a persona definition whose `iam_groups` array contains that group.
3. The persona JSON is injected into the system prompt payload that Q receives, allowing tone, preferred sources, and glossary aliases to steer retrieval.

Deployments can either mount these files directly (for example via CodePipeline artefacts) or publish them to S3 and read them at runtime. Keep the JSON stable and reviewable here so guardrails remain auditable.

## Adding a persona

1. Copy an existing JSON file as a starting point.
2. Provide a unique `id`, description, IAM group mapping, and any guidance arrays needed for the role.
3. Validate with `jq empty 02-qbusiness/personas/<file>.json`.
4. Commit the change and ship through the standard stage → promote flow.

## Runtime expectations

* The app should surface a clear error if no persona matches the caller’s group (fallback to default system prompt).
* Changes to persona files are governance-controlled by CODEOWNERS and branch protection; treat updates as configuration changes requiring review.
