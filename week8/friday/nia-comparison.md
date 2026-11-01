# KijaniKiosk delivery approach: Week 7 and Week 8

## Executive view

Week 8 turns the payments service from something an engineer can start in a prepared environment into a versioned delivery that can be repeated from committed project files. The production image is built in separate build and runtime stages, published to a private registry, retrieved again, and used by a deployment with two running instances. A stable address gives callers one entry point while the platform replaces a deleted instance.

The strongest evidence is measurable. The fresh recovery test on 1 November 2026 deleted one instance at 08:13:17 +03:00 and confirmed two running instances again at 08:13:22 +03:00: five seconds elapsed. The recorded baseline image was 187,090,813 bytes and the production image retrieved from the registry was 81,923,601 bytes. That is a reduction of 105,167,212 bytes, or approximately 56.2%. These are the observed baseline and production build sizes; the available evidence does not independently establish their Monday and Tuesday collection dates.

| Concern | Week 7 | Week 8 |
|---|---|---|
| Deployment mechanism | Thursday's exploratory cluster deployment was applied interactively. The available record does not establish a complete repeatable release path. | Committed workload and service definitions describe the desired state; a versioned image is published to a private registry and retrieved using a named image-pull secret. |
| Rollback mechanism | No verified Week 7 rollback procedure or rollback result is present in the available evidence. | Versioned image tags make a previous release identifiable and redeployable, but an actual rollback has not yet been tested or captured. |
| Failure recovery | Thursday included a Pod-deletion self-healing exercise, but its original T0, T1 and duration are not available in the current evidence. | A fresh deletion test on 1 November measured five seconds from deletion to restoration of two running replicas. |
| Scaling | The available Week 7 record does not confirm a tested scaling procedure or measured result. | The Deployment declares two replicas. The replica count can be changed declaratively, but automatic scaling has not been configured or tested. |

## What changed

The important change is repeatability. In an interactive release, success can depend on what an engineer previously created, which image happens to be on a machine, or which values were entered during a session. Week 8 records the desired application state in version-controlled artefacts. Another engineer can inspect the image reference, instance count, resource boundaries and service port before applying the same definition.

The image is deliberately small and separates build-time material from the runtime environment. The final image is 81.9 MB, runs as the unprivileged kijani account, excludes the TypeScript compiler, and includes a health check. The reduction from the observed 187.1 MB baseline is approximately 56.2%. A smaller runtime image reduces the amount of data that must be stored and transferred, while the non-root account limits the privileges available to the application if it is compromised.

Publishing the image to a private registry adds a clear hand-off between building and running. The tag combines the package version and the repository commit identifier, so the deployed version can be traced to a specific source revision. Removing the local registry tag and pulling it again demonstrated that the published image could be retrieved independently. The deployment refers to that exact tag, and the registry credential is supplied through a cluster secret rather than written into the project files.

Two instances improve continuity when one disappears. The fresh test is stronger than simply showing that two instances are running: one was deliberately deleted, a replacement appeared, and the deployment returned to two running instances in five seconds. The stable service address continues to direct traffic to the available instances. This is useful recovery evidence, although it measures replacement and running status rather than proving that every request succeeds throughout the replacement window.

## Delivery decision

A public cloud-hosted private registry was selected because the local registry was not directly reachable from the cluster network, while the hosted registry was reachable and supported private image access. This kept the deployment tied to a real registry pull rather than bypassing the registry by copying an image into the cluster. The trade-off is that the cluster depends on valid registry credentials and network access. The secret must be maintained and rotated securely.

## Evidence limitations and next steps

The Week 7 Thursday recovery timestamps and duration were not present in the records available for this submission, so this comparison does not invent a historical figure. The image-size comparison uses the measured baseline and production image sizes, but their original weekday labels are not independently preserved. Week 8 also has not demonstrated a tested rollback, automatic scaling, or recovery from a registry outage. The five-second result is one local test, not a guarantee under load or across multiple nodes.

Week 8 does not yet make the service production-complete. It does not provide environment-specific configuration management, a dedicated readiness check to prevent traffic reaching an instance before it is ready, automated rollback, or automatic scaling. Week 9 adds ConfigMaps and Secrets for configuration outside the application image and manifest, along with readiness probes that let the platform distinguish a running process from an instance ready to receive traffic. Those controls should be added and tested before presenting this as a fully production-ready deployment.
