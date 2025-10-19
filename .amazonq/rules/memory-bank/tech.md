# Technology Stack

## Programming Languages
- **Python 3.x**: Lambda functions, automation scripts, and utilities
- **TypeScript**: API routes and frontend integration components
- **JavaScript/React**: UI components and web integration
- **Bash**: Infrastructure scripts and operational automation
- **YAML/JSON**: Configuration files and CloudFormation templates

## AWS Services
- **Amazon Q Business**: Core AI-powered knowledge management platform
- **AWS Lambda**: Custom actions and document processing functions
- **Amazon S3**: Knowledge base storage and document repository
- **AWS IAM**: Identity and access management with Identity Center integration
- **Amazon CloudWatch**: Monitoring, dashboards, and alerting
- **AWS KMS**: Encryption key management for secure storage
- **AWS CodePipeline/CodeBuild**: CI/CD automation for document sync

## Build Systems & Tools
- **AWS SAM**: Serverless Application Model for Lambda deployment
- **Make**: Primary build automation and provisioning orchestration
- **AWS CLI**: Command-line interface for AWS service interactions
- **yq**: YAML processing for configuration management
- **jq**: JSON processing and data manipulation

## Development Dependencies
- **Node.js**: Required for TypeScript compilation and React components
- **Python boto3**: AWS SDK for Python Lambda functions
- **AWS SDK for JavaScript**: Frontend AWS service integration

## Key Configuration Files
- **Makefile**: Primary automation and deployment orchestration
- **template-sam.yaml**: SAM template for Lambda function deployment
- **package.json**: Node.js dependencies for UI integration
- **.env**: Environment configuration for AWS resources
- **qbusiness-pipeline.yaml**: CloudFormation template for CI/CD

## Development Commands

### Initial Setup
```bash
# Configure AWS CLI for eu-west-1
aws configure

# Copy and configure environment
cp .env.example .env
# Edit .env with your values

# Validate prerequisites
make validate
```

### Core Provisioning
```bash
# Create Q Business application
make app

# Create index and retriever
make index && make retriever

# Setup IAM roles
make roles

# Configure S3 datasource and sync
make s3 && make sync

# Apply guardrails
make guardrails

# Create web experience
make web && make web-url
```

### Lambda Development
```bash
# Build Lambda functions
make lambdas-build

# Deploy Lambda stack
make lambdas-deploy

# Test Lambda functions
make lambdas-test
```

### Monitoring & Operations
```bash
# Deploy CloudWatch dashboard
make dashboard-deploy

# Setup monitoring alarms
make pipeline-alarms

# Check sync status
./scripts/status.sh

# Manual sync trigger
make sovereign-sync
```

## Environment Requirements
- **AWS CLI**: Version 2.x with configured credentials
- **Region**: eu-west-1 (default, configurable via REGION env var)
- **Permissions**: Admin-level AWS permissions for initial setup
- **Node.js**: Version 16+ for TypeScript/React components
- **Python**: Version 3.8+ for Lambda functions
- **yq**: YAML processor for configuration management

## Deployment Architecture
- **Region**: eu-west-1 (Ireland)
- **Environment**: Production with RUBEDO SSO integration
- **Identity Provider**: AWS IAM Identity Center
- **Storage**: S3 with KMS encryption and lifecycle policies
- **Monitoring**: CloudWatch with custom dashboards and alarms
- **CI/CD**: GitHub Actions with AWS-native CodePipeline integration