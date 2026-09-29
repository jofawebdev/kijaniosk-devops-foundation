# KijaniKiosk DevOps Delivery Notes

## 1. Purpose

This document describes the DevOps delivery practices used in the KijaniKiosk DevOps Foundation project.

The objective is to demonstrate how the principles of **Flow, Feedback, and Learning** can be incorporated into a practical software delivery workflow.

The project uses Git and GitHub to provide version control, collaboration, traceability, and controlled integration of changes.

The workflow separates stable code from development and feature work using the following branches:

- `main` — stable project baseline
- `develop` — integration branch for completed feature work
- `feature/*` — isolated branches for individual changes

For this project, the feature branch is:

```text
feature/starter-kit-files
## 2. DevOps Mindset

DevOps is not limited to a collection of tools. It is a way of working that encourages collaboration between development and operations, shortens feedback cycles, improves reliability, and promotes continuous learning.

For KijaniKiosk, the DevOps approach is represented through three interconnected principles:

1. Flow
2. Feedback
3. Learning

These principles help the team deliver changes in a controlled and repeatable manner while identifying problems early and continuously improving the engineering process.

---

## 3. Flow

### 3.1 Definition

Flow refers to the movement of work from an initial idea or requirement through development, review, integration, and eventual delivery.

A healthy delivery flow minimizes unnecessary delays, large batches of work, and avoidable handoffs.

### 3.2 Flow in the KijaniKiosk Workflow

The KijaniKiosk project uses a feature-based Git workflow:

```text
Requirement
    ↓
Feature branch
    ↓
Implementation
    ↓
Commit
    ↓
Push
    ↓
Pull Request
    ↓
Review
    ↓
Merge into develop
    ↓
Future release toward main
```

The project begins from the stable `main` branch. Development work is integrated through `develop`, while individual changes are implemented in feature branches.

For this project, the work is performed on:

```text
feature/starter-kit-files
```

This approach keeps feature work isolated from stable code and makes each change easier to understand, review, and trace.

### 3.3 How the Workflow Improves Flow

The workflow improves delivery flow by:

* Breaking work into manageable units.
* Keeping feature development isolated.
* Using meaningful commits to document progress.
* Avoiding direct changes to the stable `main` branch.
* Using Pull Requests as controlled integration points.
* Reducing the risk of unrelated changes being introduced together.
* Making work visible to other team members.

Small and focused changes also make it easier to identify where a problem was introduced.

---

## 4. Feedback

### 4.1 Definition

Feedback is information obtained from the delivery process that helps the team identify problems, validate decisions, and improve the quality of its work.

Effective DevOps practices create feedback loops as early as possible rather than waiting until the end of a project.

### 4.2 Feedback in the KijaniKiosk Workflow

The primary feedback mechanism in this project is the Pull Request.

The feature branch:

```text
feature/starter-kit-files
```

will be submitted through a Pull Request targeting:

```text
develop
```

The Pull Request provides an opportunity to review:

* Documentation quality.
* Git workflow.
* Cloud architecture reasoning.
* IAM security design.
* Network segmentation.
* Technical accuracy.
* Consistency between the architecture documents.
* Compliance with the project requirements.

Git status, commit history, and repository checks also provide feedback during development.

### 4.3 Early Feedback

Feedback should occur before changes reach the stable branch.

For example, an overly broad IAM policy can be identified during review before it becomes part of an approved architecture.

Similarly, incorrect network routing can be identified by reviewing the architecture diagram and accompanying explanation before the design is considered complete.

This demonstrates an important DevOps principle:

> Problems are generally cheaper to correct when they are identified early in the delivery process.

## 5. Learning

### 5.1 Definition

Learning means using information from development, reviews, failures, and completed work to improve future decisions and processes.

DevOps encourages teams to treat mistakes and feedback as opportunities to improve rather than simply as failures.

### 5.2 Learning in the KijaniKiosk Workflow

The KijaniKiosk project provides several opportunities for learning.

The team can learn from:

* Pull Request reviews.
* Architecture decisions.
* Security considerations.
* Network design trade-offs.
* Git workflow issues.
* Documentation improvements.
* Validation results.
* Project reflection.

For example, if a review identifies unnecessarily broad IAM permissions, the team can revise the policy and apply the lesson to future IAM designs.

If the network diagram does not clearly communicate routing, the feedback can be used to improve future architecture diagrams.

### 5.3 Continuous Improvement

Learning should result in changes to future engineering practices.

A simplified learning loop is:

```text id="c9s4qa"
Implement
    ↓
Review
    ↓
Receive feedback
    ↓
Identify lessons
    ↓
Improve the process or design
    ↓
Apply the lesson to future work
```

This creates a continuous improvement cycle rather than treating each project as an isolated activity.

---

## 6. Pull Request and Collaboration Strategy

The project uses Pull Requests to introduce controlled collaboration.

The expected workflow is:

```text id="6x2vqp"
feature/starter-kit-files
          │
          │ Pull Request
          ▼
       develop
```

The Pull Request should contain a meaningful description explaining:

* What was changed.
* Why the changes were necessary.
* Important architecture decisions.
* Security considerations.
* Validation performed.

The review process provides a formal checkpoint before the feature is integrated into `develop`.

This creates traceability because the repository history can show:

* Who created the change.
* What files were changed.
* Which commits contributed to the change.
* What feedback was provided.
* When the change was merged.

---

## 7. Why Small Changes Matter

Small and focused changes reduce cognitive load during review and make problems easier to isolate.

For the KijaniKiosk project, the Starter Kit is divided into separate documentation files:

```text id="z8qm6w"
delivery-notes.md
cloud-model.md
regions-azs.md
iam-least-privilege.md
network-topology.png
```

Each file has a clearly defined responsibility.

This separation improves maintainability and allows individual architectural decisions to be reviewed independently.

---

## 8. DevOps Flow, Feedback, and Learning Relationship

Flow, Feedback, and Learning should not be considered independent concepts.

They form a continuous cycle:

```text id="5dy9bh"
                    ┌─────────────┐
                    │    Flow     │
                    │ Move work   │
                    │ efficiently │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Feedback   │
                    │ Review and  │
                    │ validate    │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Learning  │
                    │ Improve the │
                    │ process     │
                    └──────┬──────┘
                           │
                           └──────────► Improved Flow
```

Efficient flow allows work to reach review quickly.

Feedback identifies problems and validates decisions.

Learning converts that feedback into improved engineering practices.

The cycle can then be repeated for future changes.

---

## 9. Engineering Benefits

Applying these principles to KijaniKiosk provides several benefits.

### Traceability

Git records changes and provides a history of how the project evolved.

### Collaboration

Pull Requests provide a structured mechanism for reviewing work.

### Early Problem Detection

Review and validation can identify problems before changes reach stable branches.

### Security Improvement

Security decisions such as IAM permissions can be reviewed before adoption.

### Reliability Improvement

Architecture decisions can be challenged and refined before infrastructure is deployed.

### Continuous Improvement

Lessons from reviews and project reflections can influence future engineering decisions.

---

## 10. Project Application

The principles in this document are applied directly to the KijaniKiosk project.

| DevOps Principle | KijaniKiosk Implementation                                       |
| ---------------- | ---------------------------------------------------------------- |
| Flow             | Feature branch → commits → Pull Request → `develop`              |
| Feedback         | Pull Request review, validation, and architecture review         |
| Learning         | Reflection, review feedback, and improvement of future decisions |
| Collaboration    | Git branches and Pull Requests                                   |
| Traceability     | Git commits and Pull Request history                             |
| Quality          | Documentation review and validation                              |
| Security         | IAM and network architecture review                              |
| Reliability      | Region and multi-AZ architecture reasoning                       |

---

## 11. Conclusion

The KijaniKiosk workflow demonstrates that DevOps is not simply about using cloud services or automation tools.

The approach combines collaboration, version control, controlled delivery, feedback, security awareness, architectural reasoning, and continuous learning.

By using feature branches, meaningful commits, Pull Requests, and documented architectural decisions, the project establishes an engineering workflow that can be expanded as the KijaniKiosk platform grows.

The most important outcome is not the complexity of the infrastructure but the ability to make engineering decisions deliberately, document those decisions clearly, obtain feedback, and use what is learned to improve future work.

## 12. Project Reflection

### 12.1 Where Was I Most Tempted to Take Shortcuts?

The main shortcuts I was tempted to take were combining the documentation into fewer files, skipping validation after making changes, and creating the architecture diagram without explicitly documenting the routing and security decisions. These approaches would have reduced the immediate amount of work, but they would also have reduced traceability and made the project less representative of a professional DevOps workflow.

I therefore followed a more disciplined process by separating the architecture topics into focused documents, using Git branches and meaningful commits, validating the repository before progressing, and documenting the reasoning behind the major cloud, reliability, networking, and security decisions.

### 12.2 Which Architecture Decision Required the Most Reasoning?

The architecture decision that required the most reasoning was determining how the application should use cloud services while balancing developer productivity, operational responsibility, scalability, security, and future flexibility.

The service-model analysis considered Infrastructure as a Service (IaaS), Platform as a Service (PaaS), and Software as a Service (SaaS). The project selected PaaS as the initial hosting model because it can reduce infrastructure-management responsibilities while allowing the development team to concentrate on application delivery. However, IaaS remains a valid alternative if future requirements introduce greater infrastructure-level control.

The region and availability-zone decision also required careful consideration because reliability should be designed without introducing unnecessary complexity. The initial architecture therefore uses multiple availability zones within a primary region, while leaving multi-region deployment as a future consideration when the application's availability and disaster-recovery requirements justify the additional complexity.

### 12.3 If the Platform Grows Significantly, What Would I Improve First?

If KijaniKiosk grows significantly, I would first strengthen the platform's observability and reliability foundations. This would include centralized logging, application and infrastructure metrics, actionable monitoring alerts, health checks, automated recovery mechanisms, and clearly defined recovery objectives.

After establishing strong observability, the architecture could evolve through additional capacity management, automated scaling, stronger deployment automation, improved disaster-recovery capabilities, and potentially multi-region architecture where justified by documented business and availability requirements.

This approach follows the DevOps principle of making system behavior measurable before attempting to optimize or scale it. Better visibility would provide evidence for future architectural decisions rather than relying on assumptions.

