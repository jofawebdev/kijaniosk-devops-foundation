# KijaniKiosk CI Pipeline: Board Briefing

## Executive summary

KijaniKiosk needs a consistent way to assess software changes before they become release candidates. Manual checks are difficult to reproduce, and defects found late can increase recovery time and delivery risk. This continuous integration (CI) pipeline automates five stages—Lint, Build, Verify, Archive, and Publish—to produce repeatable evidence about each proposed change. A change must pass the required checks before publication is attempted.

## From source code to package

The pipeline checks out a repository revision and runs in a pinned Node.js container. A fixed runtime reduces differences between build environments. The Lint stage checks basic source conventions. If linting fails, the pipeline stops early instead of spending resources on code that already violates the project's rules.

The Build stage creates a distributable payment-validation module and checks that the output exists and is not empty. The Verify stage runs automated tests and a dependency security audit in parallel. Tests cover valid payments and invalid amounts, currencies, and inputs. The audit checks the lockfile against known dependency vulnerabilities. Parallel execution can shorten feedback time, while the overall stage still fails if a required verification branch fails.

After successful verification, Archive fingerprints and retains the build output and package metadata. This supports traceability between a build and the files it produced. Publish assigns a prerelease version combining the package's base semantic version and the source commit identifier. The intended destination is a controlled Nexus npm hosted repository.

## Stage controls

| Stage | Control and evidence | Failure response |
|---|---|---|
| Lint | Source conventions | Stop and correct the source |
| Build | Build command and output assertion | Stop; inspect build output |
| Verify | Automated tests and dependency audit | Stop; fix the failing check |
| Archive | Retained files and fingerprints | Investigate missing or invalid output |
| Publish | Versioned package and registry response | Check repository reachability and credentials |

## Failure handling and security

The pipeline uses a timeout and disables concurrent builds in the same job to reduce the risk of overlapping runs. Jenkins credentials should be stored in its credential store and injected only into the publication step. Secrets must not be committed to source control or printed to logs. The publication script should disable shell tracing while handling authentication data and remove its temporary npm configuration when it exits.

A failed stage should leave an actionable log identifying the check that failed. Recovery should correct the underlying problem and rerun the pipeline; disabling a required control is not an acceptable shortcut. The fault-injection log records the planned test, observed result, and recovery for each stage. Results must be filled from actual Jenkins runs.

## Release evidence and limitations

A successful local lint, test, build, and audit run provides useful development evidence, but it does not prove that Jenkins can execute the pipeline or that Nexus accepted a package. Those claims require a real Jenkins build and a successful registry publication. The team should retain the build log, test results, package version, source commit, archive fingerprint, and registry URL as release evidence.

The package's commit-derived version improves traceability, but it is not by itself proof of correctness or security. The dependency audit only evaluates the dependencies represented in the lockfile and the vulnerability information available to the audit service. A green CI run is therefore a quality gate, not a guarantee that defects are impossible.

## Recommendation

Adopt the pipeline as the repeatable baseline after validating it in the target Jenkins and Nexus environment. Review failures rather than bypassing controls, keep credentials restricted to the publishing stage, and confirm that two different source commits produce two distinct package versions. This gives the board evidence of repeatability and traceability while making the remaining operational dependencies explicit.
