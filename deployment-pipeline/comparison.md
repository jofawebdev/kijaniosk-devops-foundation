# Blue/Green Deployment vs Containerized Kubernetes Deployment

## Overview

KijaniKiosk uses two deployment approaches to reduce release risk. The staging blue/green design runs two application versions on a virtual machine and uses Nginx to direct traffic to the selected environment. The container delivery design packages the payments application into a production image and runs replicas through Kubernetes. Both approaches separate deployment from customer-facing traffic, but they provide different operational capabilities.

## Comparison

| Area | VM Blue/Green | Containers and Kubernetes |
|---|---|---|
| Deployment mechanism | Two systemd services run separate release directories and ports; Nginx selects the active upstream. | A container image is declared in a Kubernetes Deployment; the cluster maintains the desired replica count. |
| Rollback mechanism | Change the Nginx upstream back to the previous environment and verify its health. | Revert the Deployment image or use rollout history/undo, subject to retained revisions and image availability. |
| Failure recovery | A monitor can detect a failed active service and invoke the switch script. The end-to-end automated rollback drill was not verified in this project. | Kubernetes replaces failed or deleted Pods to maintain the declared replica count. This project measured replacement readiness in five seconds during a Pod deletion test. |
| Scaling | Capacity is limited to the VM's resources and the two configured application instances. | Replica count can be changed independently of a single application process; cluster capacity still limits available replicas. |

## Evidence and outcomes

The staging application ran blue version `v1.3.0` on port 3000 and green version `v1.4.0` on port 3001. Nginx was successfully switched to green and returned the green health response. The upstream was then restored to blue and the proxy returned `v1.3.0`. These checks demonstrate manual traffic switching and restoration.

The post-deployment monitor and switch scripts were implemented and syntax-checked. However, the failure-injection sequence did not occur while the monitor was watching green. Consequently, automatic rollback is documented as implemented but not demonstrated; no automatic rollback recovery time is claimed.

The production container image was reduced from 187,090,813 bytes to 81,923,601 bytes, a reduction of approximately 56.2% (105,167,212 bytes). The image uses a non-root runtime user and a production-focused image. Kubernetes deployed two payments replicas, exposed the application through a NodePort service, and passed service health checks. Deleting a Pod resulted in a replacement becoming ready in five seconds in the recorded test.

## Trade-offs and next steps

Blue/green on a VM is comparatively easy to inspect: two service processes, two ports, and one proxy upstream. It is useful for learning release isolation and traffic control, but it depends on careful scripting, health verification, and the capacity of one host. A proxy change alone is not proof that the new application is healthy.

Kubernetes adds declarative desired state, replica management, and workload scheduling. It can replace failed Pods, but that behavior is not the same as application-level rollback. A Deployment rollout can still introduce a bad version if readiness checks are weak or the application reports healthy while business behavior is broken.

The next orchestration iteration should add readiness and liveness probes, controlled rolling-update limits, explicit rollback procedures, externalized configuration, secrets management, resource monitoring, and alerting. It should also test a failed rollout and document the observed recovery time. These improvements would strengthen the evidence without overstating what the current project proves.

## Conclusion

The VM exercise demonstrates versioned releases and proxy-based traffic switching. The container/Kubernetes exercise demonstrates reproducible packaging, replica management, and measured Pod recovery. They complement one another: blue/green clarifies traffic cutover, while Kubernetes provides a platform for declarative deployment and workload recovery.
