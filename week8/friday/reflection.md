# Week 8 Reflection

## 1. Which step would be hardest to automate reliably, and what failure concerns you most?

The registry authentication and image publication hand-off would be the hardest step to make reliable. The automated job must obtain credentials securely, authenticate to the correct registry, publish the exact version tag, and make that image available to the cluster. A successful login does not prove that the token has permission to publish. I encountered this distinction when the first push uploaded layers but the registry rejected the manifest. The most concerning automated failure would be a job reporting success after building an image but failing to publish the expected tag. A later deployment could then pull an older image or fail with an unavailable tag. I would make the pipeline verify the pushed digest and perform a fresh pull before allowing deployment.

## 2. Rewrite one plain-language sentence for Tendo. What is lost and gained?

Plain-language sentence: "The service replaced a deleted instance and returned to two running instances in five seconds."

Technical version: "The Kubernetes Deployment controller reconciled the desired replica count after deletion of Pod `kk-payments-7c5d9fd47b-hj6z8`, creating replacement Pod `kk-payments-7c5d9fd47b-dd8q8`; two replicas were Running at T1, five seconds after T0."

The technical version gives Tendo the resource types, controller behaviour, instance identifiers and exact measurement boundaries. The plain-language version removes implementation detail and makes the operational result easier for a board member to understand. What is lost is diagnostic precision; what is gained is clarity and a direct explanation of the business outcome. Both versions are useful, but they serve different readers.

## 3. Which hardcoded values should move into ConfigMaps or Secrets in Week 9?

The image reference and application version should become environment-specific release configuration so development, test and production can select approved versions without editing the workload definition. The `PORT` value should move into a ConfigMap because it is ordinary runtime configuration and may differ between environments. CPU and memory requests and limits should also be managed as environment-specific configuration because capacity requirements can differ between environments and workloads.

The registry credential must remain in a Secret, not in the workload definition or a committed file. The current manifest correctly refers to the secret by name rather than containing the token. Any future database password, payment-provider credential, signing key or other sensitive value must also be supplied through a Secret. Keeping environment-specific values hardcoded makes promotion between environments error-prone and encourages configuration drift. Keeping sensitive values in ordinary manifests risks exposing credentials through source control and review history.
