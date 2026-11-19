# Week 4 Environment Setup

## Purpose

This document records the local environment required to reproduce the KijaniKiosk staging infrastructure. It is not proof of a successful deployment.

## Prerequisites

- Ubuntu with KVM/QEMU and libvirt enabled.
- Terraform and Ansible installed.
- Python 3, Git, and SSH.
- A working libvirt default network and storage pool.
- An SSH key pair at ~/.ssh/id_ed25519 and ~/.ssh/id_ed25519.pub.
- A local S3-compatible backend at http://127.0.0.1:9000.
- The backend bucket kijanikiosk-tfstate.

## Preflight checks

Run the following from a normal terminal:

```bash
terraform version
ansible --version
ansible-galaxy collection list community.general
virsh -c qemu:///system net-list --all
virsh -c qemu:///system pool-list --all
test -r ~/.ssh/id_ed25519.pub
```

Install the required Ansible collection if it is missing:

```bash
ansible-galaxy collection install community.general
```

## Backend credentials

The pipeline expects backend credentials in:

~/.config/kijaniosk-week4/minio.env

Keep this file outside the Git repository and restrict access to its owner. Never paste credentials into documentation or commit them to source control.

The Terraform backend uses the S3-compatible service and a dedicated state key. Verify that the backend supports the object operations and lockfile behavior required by the Terraform configuration before relying on it for concurrent team operations.

## Running the pipeline

From the repository root, run:

```bash
./week4/friday/scripts/pipeline.sh
```

The pipeline initializes and validates Terraform, applies the declared infrastructure, obtains real IP addresses from Terraform outputs, generates a local Ansible inventory, and runs the Ansible playbook. It should stop when a command fails.

## Repeatability evidence

Capture the actual output of the first and second pipeline runs. After the infrastructure has settled, run a Terraform plan and retain its real output. The second plan should propose no infrastructure changes. A second Ansible run should report changed=0 for every configured host.

Do not fabricate or edit output to make a failed run appear successful. Record errors and unresolved blockers.

## Known limitations

The virtual machines depend on host virtualization, libvirt networking, storage permissions, and Ubuntu image availability. A guest that cannot start because QEMU cannot read its base image is an infrastructure failure that must be resolved before Ansible can configure it.

The current service command is a minimal Python HTTP server used as a staging placeholder. It does not represent the full KijaniKiosk application. Production readiness requires the actual application, approved secret management, health checks, a reviewed network policy, and a backend with suitable reliability and recovery controls.
