# AI Governance Log

## Entry 1: Kubernetes deployment configuration
- Tool: ChatGPT
- AI output: Initial Kubernetes Deployment and environment overlay.
- What was wrong: The initial image configuration depended on private GHCR credentials that were not present in the staging namespace.
- Reviewer change: Changed the staging image workflow to support local Minikube image loading and explicit image verification.
- Governance control: Least privilege and environment isolation.
- Verification: Kubernetes pod events and rollout status.

## Entry 2: Jenkins deployment pipeline
- Tool: ChatGPT
- AI output: Proposed automated staging deployment and production approval gate.
- What was wrong: A pipeline that deploys without a successful staging smoke test could promote an unhealthy application.
- Reviewer change: Require staging rollout and health verification before exposing the production approval stage.
- Governance control: Separation of duties and deployment approval.
- Verification: Jenkins stage results and recorded approval.
