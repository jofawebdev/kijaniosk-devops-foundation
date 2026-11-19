# Week 4 Integration Notes

## Objective

The Week 4 pipeline connects Terraform infrastructure provisioning with
Ansible configuration management. Terraform describes the staging machines;
Ansible configures the application accounts, directories, firewall, logging,
and systemd services.

## Pipeline sequence

1. Check required local tools, SSH material, and backend credentials.
2. Initialize the Terraform working directory and backend.
3. Validate the Terraform configuration.
4. Apply the infrastructure configuration.
5. Read Terraform outputs and generate an Ansible inventory.
6. Run the Ansible playbook against the generated inventory.
7. Review the command exit statuses, Ansible recap, and repeat-run behavior.

The pipeline should stop when a required command fails. Credentials must be
supplied through local environment configuration and must never be committed
to Git or copied into submitted logs.

## Infrastructure design

The Terraform root configuration defines three service roles: API, payments,
and logging. A reusable application-server module is used to reduce
duplication. The service definitions are intended to be managed through
Terraform iteration, with outputs supplying the host information required by
Ansible.

The current development environment uses local libvirt/KVM for virtual
machines and an S3-compatible service for remote Terraform state. The backend
must be reachable and its credentials available before state operations can
succeed. Infrastructure changes should be reviewed through a plan before
applying them.

## Configuration management

The Ansible playbook is responsible for installing required operating-system
packages, creating service identities and directories, configuring systemd
units, setting up persistent journaling and log rotation, applying firewall
rules, and checking service state.

The intended repeatability test is to run the playbook twice against the same
healthy hosts. The second run should report no unintended changes. A
`changed=0` result is meaningful only when the playbook actually reached the
target hosts and completed its relevant tasks; syntax validation alone is
not an idempotency test.

## Validation status

The following static checks passed:

- Terraform recursive formatting check.
- Terraform configuration validation.
- Shell syntax validation of the pipeline script.
- Ansible playbook syntax check.
- Git whitespace and patch check.

End-to-end validation is not yet complete. A Terraform/libvirt attempt failed
when QEMU could not access the Ubuntu base image. Until that issue is
diagnosed and resolved, successful VM creation, Ansible configuration,
service health, and second-run idempotency must not be claimed.

## Evidence to capture

Save genuine output from each actual run in the evidence directory:

- `pipeline-run1.log`: first pipeline attempt, including failures.
- `pipeline-run2.log`: subsequent attempt, including its actual outcome.
- `destroy-output.txt`: output only if a deliberate, reviewed destroy operation
  is actually performed.

Do not replace a failed log with fabricated success output. Redact secrets,
tokens, private keys, and sensitive backend values before submitting evidence.
Do not destroy infrastructure merely to create an evidence file.

## Outstanding actions

1. Diagnose the QEMU image-access failure using the domain logs and libvirt
   configuration.
2. Apply only a targeted, verified permissions or configuration correction.
3. Re-run Terraform and capture the real result.
4. If provisioning succeeds, run Ansible and capture the PLAY RECAP.
5. Re-run Ansible to test idempotency and record the second recap.
6. Review the Terraform plan and any destroy operation before approval.
7. Commit the documentation and genuine evidence, then update the Week 4 PR.

## Acceptance criteria

The project is ready for an end-to-end success claim only after infrastructure
provisioning succeeds, Ansible reaches the intended hosts, the services and
security settings are verified, and repeat-run results support the
idempotency claim. Until then, report the static checks as passed and the
deployment blocker as unresolved.
