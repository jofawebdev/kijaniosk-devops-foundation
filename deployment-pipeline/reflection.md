# Deployment Pipeline Reflection

## 1. What plain-language explanation could overclaim?

Saying that Kubernetes automatically rolls back a bad release would overclaim. Kubernetes can restart containers and replace failed Pods, but that does not necessarily mean it recognizes a business-level regression and restores the previous application version. A Pod can be healthy while payment behavior is wrong. Rollback needs an explicit rollout strategy, health criteria, monitoring, and an operational decision or automation.

## 2. Highest-value incident action

The highest-value action is to verify the candidate version through the actual staging proxy before considering a deployment complete, and to keep a tested restoration path available. This reduces the risk of exposing a version that starts successfully but cannot serve traffic. Confidence is based on the successful blue and green proxy health checks in this project. The automated failure-triggered rollback remains unverified, so a timed fault-injection test and captured logs are still needed before claiming that recovery is automatic.

## 3. What transfers from blue/green to Kubernetes?

The transferable concepts are version separation, health-based promotion, traffic control, rollback planning, and evidence-based verification. Kubernetes can implement related ideas through Deployments, rollout controls, Services, readiness probes, and revision history. The VM-specific work of editing an Nginx upstream and managing two systemd services is largely replaced by Kubernetes resources and controller behavior. The operational principle remains: do not promote a release merely because its process starts.

## 4. What should be externalized?

Hardcoded deployment settings such as application version, environment-specific configuration, replica counts, and resource limits should be managed through versioned deployment configuration. Non-sensitive settings belong in ConfigMaps or equivalent configuration mechanisms; credentials and tokens belong in Secrets or a dedicated secret manager, never in source control or image layers. Externalizing configuration makes changes reviewable and environment-specific without rebuilding application code. It also introduces responsibility for access control, secret rotation, validation, and keeping configuration consistent with the deployed release.
