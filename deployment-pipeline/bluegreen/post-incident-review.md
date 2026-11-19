# Post-Incident Review: Staging Demonstration Interruption

**Incident duration:** 48 seconds (scenario-provided)  
**Environment:** KijaniKiosk staging  
**Review status:** Reconstructed exercise; original event logs were not supplied.

## 1. Summary for a non-technical audience

During an investor demonstration, the staging application was unavailable for 48 seconds. The interruption affected the demonstration but did not establish that customer production payments were affected. The review focuses on making releases safer and ensuring the previous working version can be restored quickly.

## 2. Timeline

The assignment scenario supplies the 48-second duration but not timestamped event logs. The following sequence is therefore a reconstruction, not an independently verified chronology:

- **T−:** A staging release or traffic change was being demonstrated. Exact timestamp and action are unavailable.
- **T+0:** Staging became unavailable to the demonstration.
- **T+48 seconds:** Staging recovered, according to the scenario.
- **After recovery:** The incident was reviewed for deployment verification and rollback improvements.

Do not treat these relative entries as measured timestamps.

## 3. Root cause analysis (hypothesis)

The scenario does not provide a confirmed technical root cause. A plausible hypothesis is that a release/cutover changed the active traffic path before the candidate environment was fully verified.

Four why questions:

1. Why was staging unavailable? The demonstration traffic could not obtain a usable application response.
2. Why might the response have failed? The active proxy path may have pointed to an unavailable or incorrectly configured application instance.
3. Why could that reach the demonstration? Candidate health may not have been verified through the same proxy path before promotion.
4. Why was recovery not immediate? The restoration path and failure detection may not have been rehearsed or automated end-to-end.

This is a hypothesis to validate against Nginx, application, and systemd logs; it is not a confirmed finding.

## 4. Contributing factors

- Release verification may have relied on process status or direct health rather than proxy health.
- The cutover and restoration sequence may not have been rehearsed under failure.
- Monitoring and evidence collection were not demonstrated as a complete automated rollback drill.
- Staging availability and production availability were not clearly separated in the incident narrative.

## 5. What went well

- The staging setup provides separate blue and green application instances.
- Nginx can route to either version and both versions returned healthy responses during later verification.
- The previous version could be restored through a controlled upstream switch.
- The incident duration was bounded at 48 seconds in the scenario.

## 6. Corrective actions

| Action | Owner role | Target |
|---|---|---|
| Verify candidate direct health and proxy health before promotion; fail closed on mismatch. | Deployment engineer | Before next release |
| Run and record an end-to-end failure-triggered rollback drill, including timestamps and expected version. | DevOps engineer | Within 1 week |
| Add request availability, latency, and payment error metrics with alerts. | Observability owner | Within 2 weeks |
| Capture and retain proxy, application, and service logs during deployment. | Platform engineer | Within 1 week |
| Rehearse the demo using a staging release checklist and a known rollback operator. | Demo lead | Before next investor demo |

## Learning

The incident reinforces that a successful process start is not equivalent to a successful release. A deployment should be promoted only after the intended traffic path is healthy, and recovery claims should be supported by a timed drill.
