# Week 5 Reflection

## 1. Where is the tension between speed and safety?

Parallel verification reduces waiting time because automated tests and the dependency audit can run concurrently. However, concurrency must not weaken the release gate: both checks must succeed before archiving and publishing. The pipeline also needs a timeout and controlled concurrency to avoid stuck or overlapping builds. Speed is useful only when the evidence remains trustworthy.

## 2. How does the board explanation differ from the technical explanation?

The board briefing focuses on delivery risk, repeatability, traceability, and the meaning of a failed check. An engineer needs the implementation details: commands, runtime image, test assertions, credential bindings, artifact paths, and console logs. Both audiences need accurate evidence, but the board needs the impact and decision while the engineer needs enough detail to reproduce and fix the result.

## 3. What becomes the pressure point as the project scales?

The artifact repository and credential configuration are important operational dependencies. As teams and build frequency increase, registry availability, retention policies, access controls, and artifact naming become more consequential. Build agents also need enough capacity to run parallel checks. The team should monitor queue time and failure rates, protect credentials, retain artifacts deliberately, and ensure that each published package can be traced to its source commit.
