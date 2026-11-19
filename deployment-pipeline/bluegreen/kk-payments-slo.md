# KijaniKiosk Payments: Proposed SLI/SLOs

**Status:** Proposed targets for a staging service; not production measurements.

## Service indicators and objectives

| SLI | Definition and source | Proposed 30-day SLO |
|---|---|---|
| Availability | Successful health and application requests divided by eligible requests; measured from proxy/application monitoring. | At least 99.5% successful requests. |
| Latency | Percentage of successful requests completing within 500 ms; measured from request-duration metrics. | At least 95% within 500 ms. |
| Payment error rate | Non-validation server failures divided by attempted payment requests; measured from structured application logs/metrics. | No more than 1% server-side payment errors. |

## Measurement and review

Use a rolling 30-day window for each objective. Exclude planned maintenance only when it is announced and recorded in advance; do not silently exclude incidents. Report request counts alongside percentages so low-volume periods are not misleading. These targets require instrumentation before they can be evaluated reliably.

## Deployment and rollback thresholds

Proposed deployment guardrails:

- Stop promotion if the candidate fails three consecutive health checks or cannot be verified through the staging proxy within 30 seconds.
- Initiate rollback consideration if server-side payment errors exceed 5% over a rolling five-minute window with at least 20 requests.
- Initiate rollback consideration if fewer than 90% of requests meet the 500 ms latency threshold over five minutes with at least 20 requests.
- Confirm the previous version through the proxy after restoration; record timestamps, version, and operator/action.

These are proposed operational thresholds, not observed production policies. A low request count should trigger investigation rather than an unqualified percentage-based decision.

## Metrics intentionally excluded

CPU utilization and memory utilization are useful capacity indicators, but they are not direct customer outcome SLIs. Pod count or service process status is also not sufficient to establish successful payment behavior. They should be monitored as supporting signals, not substituted for availability, latency, or payment correctness.
