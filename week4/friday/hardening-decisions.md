# KijaniKiosk Security and Hardening Decisions

## Purpose

This document explains the security decisions for the KijaniKiosk staging
environment in language suitable for technical reviewers and nontechnical
stakeholders. The objective is to reduce unnecessary access, limit the impact
of a compromised service, and make the environment easier to operate and
review. These controls are intended to support a repeatable staging deployment;
they do not, by themselves, constitute proof of a successful production
deployment or independent security certification.

## Security controls

| Control | What it does | Risk mitigated |
|---|---|---|
| Dedicated service accounts | Runs the API, payments, and logging services under separate accounts rather than one shared application identity. | Limits the damage one compromised service can cause to other services and files. |
| Least-privilege group access | Uses a dedicated application group and controlled directory permissions for shared application resources. | Reduces unauthorized access to configuration, logs, and application data. |
| Network segmentation | Restricts selected service ports to the intended staging network while keeping payments bound to loopback in the current design. | Reduces exposure of internal services to untrusted networks. |
| Default-deny inbound firewall | Blocks unsolicited inbound connections unless a rule explicitly permits the required traffic. Outbound traffic is allowed by the current playbook. | Reduces the number of network paths available to an attacker. |
| SSH administration | Allows SSH as an explicit administrative access path. Access should be limited further through approved keys, account controls, and network restrictions. | Reduces the risk of unmanaged remote administration. |
| System service isolation | Uses systemd service settings such as `NoNewPrivileges`, `PrivateTmp`, `PrivateDevices`, and filesystem protection. | Limits privilege escalation and reduces access to unrelated system resources. |
| Restricted filesystem writes | Enables `ProtectSystem=strict` and explicitly permits writes only to required application locations. | Reduces the chance that a compromised process can modify operating-system files. |
| Reduced Linux capabilities | Uses an empty capability bounding set for the application service where supported by the service design. | Removes powerful operating-system privileges that the application should not require. |
| System call restrictions | Applies a systemd system-service syscall filter. | Reduces the range of kernel interfaces available to a compromised process. |
| Persistent, bounded journals | Configures persistent system logging and size limits for retained journal data. | Improves incident investigation while limiting uncontrolled log growth. |
| Log rotation | Rotates application logs, compresses older logs, and limits retention. | Reduces disk exhaustion and preserves a manageable history of operational events. |
| Reproducible infrastructure | Defines the staging machines and their configuration as code, rather than relying only on undocumented manual setup. | Reduces configuration drift and makes changes easier to review and repeat. |
| Remote Terraform state | Uses an S3-compatible backend with a dedicated state location and state locking support. | Helps maintain a shared record of infrastructure and reduces conflicting state operations. State access and backend availability still require protection and monitoring. |

## Design and operational considerations

The environment separates the API, payments, and logging roles. Each role
has its own service identity and configured port. The payments service is
configured to listen on loopback, so it is not intended to accept direct
connections from remote clients. The API and logging service ports are
subject to the configured staging-network firewall rules. These settings
must be checked against the actual network topology before the environment
is treated as ready for external use.

The application service units use operating-system isolation controls to
limit privileges and writable locations. These controls should be reviewed
alongside application requirements: a service that genuinely needs additional
filesystem or network access should receive only the specific permission
required, rather than disabling hardening globally.

Infrastructure state contains sensitive operational information. Backend
credentials must be stored outside version control, restricted to the
appropriate local user, and never included in logs or submitted as evidence.
State locking is useful only when the backend supports it correctly and the
configuration is initialized and tested against that backend.

## Verification and known limitations

Configuration syntax checks have passed for Terraform formatting and
validation, the pipeline shell script, and the Ansible playbook syntax.
Those checks establish that the relevant files parse and validate; they do
not prove that the virtual machines boot, that firewall rules behave as
intended, or that services survive a reboot.

A VM provisioning attempt encountered a permission error while QEMU accessed
the Ubuntu base image. This is a deployment blocker that must be resolved
and retested before claiming a successful end-to-end run. The current
evidence does not establish a successful Ansible convergence or a second run
with zero changes.

The playbook's application services currently use Python's HTTP server as a
staging placeholder, not a complete payment-processing implementation.
Before production use, the team would need a real application, authenticated
health checks, secret management, TLS, monitoring and alerting, a reviewed
backup and recovery procedure, and security testing appropriate to the
service.

## Conclusion

The design applies defense in depth: dedicated identities, constrained
network access, service isolation, bounded logging, and infrastructure as
code complement one another. The controls should be considered implemented
only where supported by the committed configuration and verified in the
running environment. Deployment and repeatability evidence remains necessary
before the staging environment can be declared successfully provisioned.
