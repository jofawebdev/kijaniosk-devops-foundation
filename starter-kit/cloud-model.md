# KijaniKiosk Cloud Service Model

## 1. Purpose

This document evaluates the three major cloud service models — Infrastructure as a Service (IaaS), Platform as a Service (PaaS), and Software as a Service (SaaS) — in the context of the KijaniKiosk platform.

The purpose is to identify the service model that best supports the platform's initial technical requirements while considering operational responsibility, scalability, security, maintainability, and DevOps practices.

The analysis focuses on architectural reasoning rather than selecting services solely by popularity or convenience.

---

## 2. KijaniKiosk Cloud Requirements

KijaniKiosk is an online platform that requires an environment capable of supporting application development, deployment, data storage, networking, security controls, monitoring, and future growth.

The initial architecture should therefore consider the following requirements:

* Reliable hosting for the application.
* A controlled deployment environment.
* Secure access to application resources.
* Persistent data storage.
* Network isolation and traffic control.
* Ability to scale as usage increases.
* Reasonable operational complexity for the engineering team.
* Support for DevOps practices and automation.
* Clear separation of application and infrastructure responsibilities.
* Ability to integrate monitoring, logging, and security controls.

The selected cloud service model should provide an appropriate balance between developer productivity and control over the underlying environment.

---

## 3. Infrastructure as a Service (IaaS)

### 3.1 Definition

Infrastructure as a Service provides virtualized computing infrastructure through a cloud provider.

Typical IaaS resources include:

* Virtual machines.
* Virtual networks.
* Storage.
* Firewalls and security controls.
* Load balancing infrastructure.
* Networking components.

With IaaS, the cloud provider manages the underlying physical infrastructure, while the customer is responsible for configuring and managing many components of the operating environment.

### 3.2 Advantages of IaaS

IaaS provides a high level of infrastructure control.

Potential advantages include:

* Flexible infrastructure configuration.
* Control over operating systems and installed software.
* Ability to customize networking.
* Ability to configure security controls at the infrastructure level.
* Support for workloads with specialized requirements.
* Greater control over infrastructure architecture.

IaaS can therefore be useful when an application requires significant control over the underlying environment.

### 3.3 Limitations of IaaS

The additional control provided by IaaS also creates additional operational responsibilities.

The engineering team may need to manage:

* Operating system updates.
* Security patches.
* Server configuration.
* Capacity planning.
* System monitoring.
* Infrastructure hardening.
* Backup configuration.
* Deployment automation.

This can increase operational complexity and create additional maintenance requirements.

---

## 4. Platform as a Service (PaaS)

### 4.1 Definition

Platform as a Service provides a managed application platform on which developers can deploy applications without managing the underlying physical infrastructure and, depending on the service, much of the operating-system and runtime administration.

PaaS typically abstracts infrastructure management so that developers can concentrate more heavily on application development and delivery.

### 4.2 Advantages of PaaS

PaaS can provide several advantages for an application development team:

* Reduced infrastructure management.
* Faster application deployment.
* Greater developer productivity.
* Simplified scaling.
* Managed runtime environments.
* Integration with deployment and monitoring services.
* Reduced need to maintain operating systems manually.

PaaS can therefore support a DevOps approach by allowing the team to focus more effort on application delivery, testing, automation, and continuous improvement.

### 4.3 Limitations of PaaS

PaaS also introduces trade-offs.

Potential limitations include:

* Less control over the underlying infrastructure.
* Platform-specific configuration requirements.
* Possible vendor lock-in.
* Restrictions imposed by the managed runtime.
* Less flexibility for specialized operating-system requirements.

The team must therefore ensure that the selected platform supports the application's technical requirements.

---

## 5. Software as a Service (SaaS)

### 5.1 Definition

Software as a Service provides a complete software application through the internet.

The SaaS provider generally manages:

* Infrastructure.
* Operating systems.
* Application software.
* Updates.
* Availability of the service.
* Much of the underlying security and maintenance.

Users normally interact with the completed application rather than managing its infrastructure.

### 5.2 Advantages of SaaS

SaaS provides a high level of abstraction.

Advantages can include:

* Minimal infrastructure management.
* Rapid access to software functionality.
* Provider-managed updates.
* Reduced operational responsibility.
* Predictable access to a completed application.

### 5.3 Limitations of SaaS

SaaS is less suitable when an organization needs to build and control its own application platform.

Potential limitations include:

* Limited control over the underlying application architecture.
* Limited infrastructure customization.
* Dependence on the provider's application capabilities.
* Less control over application deployment processes.
* Potential difficulty integrating highly customized application requirements.

For these reasons, SaaS is generally more appropriate when an organization wants to consume an existing software product rather than build and operate its own platform.

---

## 6. Comparison of Cloud Service Models

| Characteristic              | IaaS                                             | PaaS                                   | SaaS                          |
| --------------------------- | ------------------------------------------------ | -------------------------------------- | ----------------------------- |
| Infrastructure control      | High                                             | Low to moderate                        | Very low                      |
| Operating-system management | Customer                                         | Mostly provider                        | Provider                      |
| Application management      | Customer                                         | Customer                               | Provider                      |
| Infrastructure management   | Shared, with significant customer responsibility | Mostly provider                        | Provider                      |
| Developer focus             | Infrastructure and application                   | Primarily application                  | Primarily usage/configuration |
| Customization               | High                                             | Moderate                               | Limited                       |
| Operational complexity      | Higher                                           | Lower                                  | Lowest                        |
| Typical use                 | Custom infrastructure and specialized workloads  | Application development and deployment | Consuming complete software   |

The models represent different levels of abstraction and responsibility.

As the level of abstraction increases from IaaS toward SaaS, the customer's infrastructure management responsibility generally decreases.

---

## 7. KijaniKiosk Service Model Consideration

KijaniKiosk is an application platform rather than a consumer of an existing software product.

Therefore, SaaS does not directly satisfy the primary requirement because KijaniKiosk itself needs to be developed and deployed.

Both IaaS and PaaS can support the platform, but they provide different balances between control and operational responsibility.

IaaS would provide greater control over the infrastructure and operating environment. However, this would also require the engineering team to manage more infrastructure components.

PaaS would reduce infrastructure management responsibilities and allow the team to concentrate more heavily on application development, deployment, monitoring, and continuous improvement.

---

## 8. Recommended Service Model

For the initial KijaniKiosk architecture, **PaaS is selected as the primary cloud service model**.

This selection is based on the project's current objective of establishing a maintainable application platform while minimizing unnecessary infrastructure-management overhead.

The decision is not based on PaaS being universally superior to IaaS or SaaS. Instead, it reflects the current requirements and scope of the KijaniKiosk platform.

---

## 9. Technical Justification

PaaS provides an appropriate balance between application control and infrastructure abstraction for the initial KijaniKiosk environment.

### 9.1 Developer Productivity

The engineering team can focus more heavily on application development and delivery instead of spending significant effort maintaining operating systems and underlying servers.

### 9.2 DevOps Alignment

A managed platform can support DevOps practices by reducing infrastructure administration and allowing the team to focus on:

* Version control.
* Automated testing.
* Continuous integration.
* Continuous delivery.
* Monitoring.
* Application reliability.
* Feedback and continuous improvement.

### 9.3 Reduced Operational Overhead

Using a managed platform can reduce the number of infrastructure components that the team must configure and maintain directly.

This is particularly relevant during the early stage of the KijaniKiosk project, where engineering effort should be concentrated on establishing a reliable application foundation.

### 9.4 Scalability

A suitable PaaS offering can provide mechanisms for increasing application capacity as demand changes.

This can reduce the amount of manual infrastructure management required as the platform grows.

### 9.5 Maintainability

Reducing the amount of infrastructure that the team manages directly can simplify maintenance and reduce the number of operational tasks that must be incorporated into the team's regular workflow.

---

## 10. IaaS as an Alternative

Although PaaS is selected for the initial architecture, IaaS remains a valid architectural option.

IaaS may become appropriate if KijaniKiosk develops requirements that require greater infrastructure control.

Examples could include:

* Specialized operating-system requirements.
* Custom networking requirements.
* Infrastructure-level software dependencies.
* Workloads requiring detailed server configuration.
* Requirements that cannot be supported effectively by the selected PaaS platform.

The choice of PaaS should therefore be treated as an architectural decision based on current requirements rather than a permanent restriction.

---

## 11. SaaS Consideration

SaaS can still be useful within the broader KijaniKiosk ecosystem.

For example, supporting organizational functions may use existing SaaS products for services such as:

* Communication.
* Project management.
* Documentation.
* Customer support.
* Business productivity.

However, these supporting SaaS products would complement the KijaniKiosk platform rather than serve as the primary hosting model for the custom application itself.

---

## 12. DevOps Considerations

The selected cloud model should support the broader DevOps workflow documented in `delivery-notes.md`.

The intended delivery cycle is:

```text
Code
  ↓
Version Control
  ↓
Automated Validation
  ↓
Deployment
  ↓
Monitoring
  ↓
Feedback
  ↓
Improvement
```

A managed application platform can reduce infrastructure-management overhead and allow engineering effort to focus on improving this delivery cycle.

The cloud architecture should therefore be integrated with version control, automated validation, deployment processes, monitoring, security controls, and documented operational procedures.

---

## 13. Scalability Considerations

The initial KijaniKiosk architecture should avoid unnecessary complexity while allowing future expansion.

If platform usage increases significantly, the architecture can evolve through measures such as:

* Application scaling.
* Load distribution.
* Database scaling.
* Caching.
* Asynchronous processing.
* Improved monitoring.
* Additional availability mechanisms.
* More advanced infrastructure controls where necessary.

The architecture should therefore support incremental evolution rather than requiring the entire platform to be redesigned whenever demand changes.

---

## 14. Shared Responsibility Consideration

Selecting a managed cloud service does not eliminate the customer's security responsibilities.

The cloud provider remains responsible for the security of the underlying services according to the selected service model, while the KijaniKiosk team remains responsible for areas under its control.

These responsibilities may include:

* Application security.
* Identity and access management.
* Secure configuration.
* Data protection.
* Access control.
* Application-level logging and monitoring.
* Secure software development practices.

The exact division of responsibility depends on the selected cloud provider and service.

---

## 15. Conclusion

IaaS, PaaS, and SaaS provide different levels of abstraction, control, and operational responsibility.

IaaS provides greater infrastructure control but requires more infrastructure management.

PaaS reduces infrastructure-management responsibilities while maintaining an environment designed for application deployment and development.

SaaS provides the highest level of abstraction and is primarily intended for consuming complete software applications rather than hosting a custom application platform.

For the initial KijaniKiosk architecture, PaaS is selected because it provides a practical balance between developer productivity, operational simplicity, scalability, and DevOps-oriented application delivery.

The decision should be revisited if the platform develops requirements that demand greater infrastructure control.

---

## 16. References

* Amazon Web Services. *AWS Well-Architected Framework*.
  https://aws.amazon.com/architecture/well-architected/

* Google Cloud. *Google Cloud Well-Architected Framework*.
  https://cloud.google.com/docs/get-started/well-architected-framework

* Amazon Web Services. *Cloud Computing with AWS*.
  https://aws.amazon.com/what-is-cloud-computing/

* National Institute of Standards and Technology. *The NIST Definition of Cloud Computing (SP 800-145)*.
  https://doi.org/10.6028/NIST.SP.800-145
