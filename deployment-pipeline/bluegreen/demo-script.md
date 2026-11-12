# KijaniKiosk Deployment Demo Script

[Show the two staging environments and the health responses.]

**Presenter:** This project demonstrates safer releases for KijaniKiosk payments. We keep a previous version available while verifying a candidate version.

[Show blue and green service status.]

**Presenter:** Blue is version one point three. Green is version one point four. Each runs separately, so we can test the candidate without replacing the current service.

[Show the proxy health response for green, then blue.]

**Presenter:** The traffic proxy can direct requests to either version. We verified a switch to green and restored blue successfully. That gives us a controlled restoration path.

[Show the container image evidence.]

**Presenter:** The production image is about fifty-six percent smaller than the earlier image. It runs as a non-root user and is published to the container registry.

[Show the Kubernetes deployment and service.]

**Presenter:** Kubernetes runs two payments replicas. In our recorded test, deleting a Pod resulted in a replacement becoming ready in five seconds.

[Show rollback evidence.]

**Presenter:** The monitor and rollback scripts are implemented, but the automatic failure-triggered drill is not yet verified. We report that limitation clearly instead of claiming an untested recovery.

[Close.]

**Presenter:** The outcome is repeatable packaging, controlled traffic switching, and measurable recovery evidence, with clear next steps for stronger monitoring and automated rollback.
