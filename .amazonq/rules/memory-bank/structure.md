# Project Structure

## Directory Organization

### Core Infrastructure
- **01-foundation/**: IAM policies, roles, and SSO group configurations
  - `iam/policies/`: Q Business admin and datasource policies
  - `iam/roles/`: Role creation scripts and GitHub OIDC setup
  - `sso/groups.yaml`: Identity Center group definitions

### Q Business Components
- **02-qbusiness/**: Complete Q Business application stack
  - `app/`: Application creation and configuration scripts
  - `index/`: Index and retriever setup
  - `datasources/`: Multi-source connectors (S3, Confluence, GitHub, Slack, GDrive)
  - `guardrails/`: Content controls and topic restrictions
  - `web/`: Web experience creation and URL management
  - `monitoring/`: CloudWatch dashboards, alarms, and metrics
  - `security/`: KMS encryption and S3 lifecycle policies
  - `personas/`: Role-based Q Apps (compliance, engineer, delivery-manager)
  - `qapps/`: Starter Q App JSONs for common workflows

### Lambda Functions
- **03-lambdas/**: Custom Q Business actions and integrations
  - `vmq-create-jira-draft/`: JIRA ticket creation automation
  - `vmq-draft-change-note/`: Change documentation generation
  - `vmq-generate-compliance-pack/`: Compliance documentation
  - `vmq-generate-faq/`: FAQ generation from documents
  - `vmq-summarize-docs/`: Document summarization
  - `vmq-validate-schema/`: Schema validation utilities
  - `common/vmq_common.py`: Shared utilities and helpers

### UI Integration
- **04-ui-integration/**: Frontend components and API routes
  - `api/`: TypeScript API routes for catalog and invoke operations
  - `components/`: React components for action handoff
  - `lib/`: AWS SDK utilities and persona management

### Operations & Monitoring
- **03-observability/**: CloudWatch notes and monitoring guidance
- **03-ops/**: Production alarm setup and Identity Center configuration
- **scripts/**: Operational scripts for sync, validation, and status checking

### Documentation & Migration
- **docs/**: Technical documentation, glossaries, and policy guides
- **04-migration/**: Migration checklists and mapping documentation
- **.github/workflows/**: CI/CD pipelines for sync, DR, and guardrail management

## Architectural Patterns

### Layered Architecture
1. **Foundation Layer**: IAM, security, and identity management
2. **Q Business Layer**: Core application, index, and data sources
3. **Integration Layer**: Lambda functions and custom actions
4. **Presentation Layer**: Web experience and UI components
5. **Operations Layer**: Monitoring, alerting, and automation

### Configuration Management
- Environment-based configuration via `.env` files
- Makefile-driven provisioning with dependency management
- CloudFormation templates for infrastructure as code
- JSON/YAML configuration files for Q Business components

### Data Flow
1. **Ingestion**: Multi-source data connectors → S3 knowledge bucket
2. **Processing**: Q Business indexing and retrieval optimization
3. **Security**: Guardrails and content filtering
4. **Delivery**: Web experience and custom Q Apps
5. **Monitoring**: CloudWatch metrics and operational dashboards

## Key Relationships
- **Foundation → Q Business**: IAM roles enable Q Business operations
- **Q Business → Lambdas**: Custom actions extend Q Business capabilities
- **Monitoring → All Layers**: Observability spans entire stack
- **UI Integration → Q Business**: Frontend components interact with Q Business APIs
- **Scripts → Operations**: Automation scripts manage lifecycle operations