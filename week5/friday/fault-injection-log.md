# CI Fault-Injection and Recovery Log

## Purpose

This log defines five controlled failure tests for the Lint, Build, Verify, Archive, and Publish stages. Run these only in a disposable feature branch and test registry. Do not introduce faults into the shared `develop` branch or production repository.

**Evidence status:** Jenkins is not yet confirmed available in this environment. Observed results must remain pending until each test is run and the actual console output is reviewed.

| Stage | Safe injection | Expected result | Observed result | Recovery |
|---|---|---|---|---|
| Lint | Temporarily introduce a prohibited `debugger` statement into a disposable source copy | Lint fails; later stages do not run | PENDING — run in Jenkins | Remove the statement and rerun |
| Build | Temporarily change the build script to exit non-zero in a disposable commit | Build fails; verification and later stages are skipped | PENDING — run in Jenkins | Restore the build script |
| Verify | Temporarily add a test that asserts an incorrect result | Test branch fails and the Verify stage fails | PENDING — run in Jenkins | Correct or remove the deliberately failing test |
| Archive | In a disposable pipeline revision, archive a deliberately nonexistent path with empty archives disallowed | Archive fails and Publish is skipped | PENDING — run in Jenkins | Restore the correct artifact path |
| Publish | Use a disposable test run with an invalid credential ID or unreachable test registry | Publish fails without exposing a secret; earlier evidence remains available | PENDING — run in Jenkins | Restore the approved credential and registry configuration |

## Execution record

For each test, record the Jenkins build number, date/time, injected fault, failing stage, downstream stages skipped, relevant console-log excerpt, and recovery build number. Never paste passwords, access tokens, or unmasked credential values into this document.

Do not mark a test PASS based on its expected result alone. Mark it PASS only after the actual build demonstrates the expected failure and the recovery run succeeds.
