# KijaniKiosk Capstone Scope

## Problem
KijaniKiosk requires a reproducible delivery process that validates application changes before production promotion, isolates staging configuration, and supports safe recovery from deployment failures.

## Track
Track A: Infrastructure-First.

## In scope
1. Terraform-managed staging namespace.
2. Ansible-managed staging configuration.
3. Shared Kubernetes application Deployment across environments.
4. Jenkins staging deployment, smoke test, and production approval gate.
5. Monitoring, health verification, and deployment evidence.

## Out of scope
1. A production-grade payment processor integration: the capstone focuses on delivery reliability.
2. Multi-region disaster recovery: outside the local staging environment and project timeframe.

## Success criteria
- Clean checkout can reproduce application build and tests.
- Staging is isolated from production configuration.
- Jenkins deploys to staging and verifies application health.
- Production deployment requires explicit approval.
- Deployment failure is detectable and recovery is documented.

## Architecture
Developer -> GitHub -> Jenkins -> Build/Test -> Registry -> Staging Kubernetes -> Smoke Test -> Approval -> Production Kubernetes

Runtime monitoring observes Kubernetes workloads and reports application health.
