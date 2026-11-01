# Jenkins and Nexus Credential Audit

## Scope

This review covers the intended Jenkins-to-Nexus package publication path. It records the credential-handling design, not a claim that a live Jenkins credential store has already been inspected.

## Required controls

| Control | Expected standard | Verification status |
|---|---|---|
| Credential storage | Store the Nexus username and password in Jenkins Credentials | PENDING live Jenkins inspection |
| Credential identifier | Reference `nexus-npm-credentials` in the pipeline | Defined in Jenkinsfile |
| Scope | Bind credentials only inside the Publish stage | Defined in Jenkinsfile |
| Secret exposure | Do not hard-code credentials or echo them | Reviewed in pipeline source |
| Shell tracing | Disable tracing while handling authentication | `set +x` in Publish |
| Temporary authentication file | Create `.npmrc` at runtime and remove it on shell exit | Cleanup trap defined |
| Repository access | Use a dedicated hosted npm repository and least-privilege account | PENDING Nexus configuration review |
| Log review | Check actual Jenkins console output for exposed secrets | PENDING live build |

## Findings and actions

The pipeline references a Jenkins credential ID rather than embedding a username or password in source control. Authentication is generated at runtime, and the temporary npm configuration is removed on shell exit. The `.npmrc` file must never be committed.

Before production use, an administrator should verify that the Jenkins credential exists, that its permissions are limited to the required publisher, and that the Nexus account can publish only to the intended hosted repository. Review actual console output and repository history for accidental secret exposure. If a real secret is exposed, revoke or rotate it immediately.

## Limitation

Source inspection cannot prove that a credential exists, has least-privilege permissions, or is masked correctly in a live Jenkins run. Those checks remain pending until Jenkins and Nexus are available.
