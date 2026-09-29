# KijaniKiosk IAM Least Privilege

## 1. Purpose

This document defines a least-privilege Identity and Access Management (IAM) design for a specific KijaniKiosk application task.

The purpose is to demonstrate how application permissions can be limited to only the resources and actions required for the application to perform its intended function.

The example focuses on an application component that needs to manage product-media objects in a dedicated object-storage location.

The design follows the principle of least privilege:

> An identity should receive only the permissions required to perform its intended task and no broader permissions than necessary.

---

## 2. Application Task

The KijaniKiosk application requires a controlled storage location for product-media files such as:

* Product images.
* Product thumbnails.
* Other application-managed media objects.

The application needs to:

1. Upload product-media objects.
2. Retrieve product-media objects.
3. Delete product-media objects when they are intentionally removed.
4. List objects within the application's dedicated storage location when required by the application workflow.

The application does **not** require administrative access to the cloud account.

---

## 3. IAM Design Principle

The IAM design follows least privilege by limiting access according to:

* Specific identity.
* Specific actions.
* Specific resources.
* Specific application purpose.

The application should receive permissions through an IAM role rather than embedding long-lived access keys directly in application source code.

The conceptual relationship is:

```text
KijaniKiosk Application
          │
          │ assumes
          ▼
   Application IAM Role
          │
          │ limited permissions
          ▼
Dedicated Product Media Storage
```

The role should only provide the permissions required by the application.

---

## 4. Proposed IAM Role

### Role Name

A descriptive role name should clearly communicate its purpose.

Example:

```text
KijaniKioskProductMediaRole
```

The role is intended only for the KijaniKiosk application component responsible for managing product-media objects.

A production naming convention should also include the relevant environment, for example:

```text
KijaniKioskProductMediaRole-Production
```

---

## 5. Required Permissions

The application requires a limited set of object-storage operations.

Conceptually, the permissions are:

| Permission     | Purpose                                             |
| -------------- | --------------------------------------------------- |
| Object read    | Retrieve product-media objects                      |
| Object write   | Upload product-media objects                        |
| Object delete  | Remove application-managed media                    |
| Object listing | List objects within the designated storage location |

The permissions should be restricted to the KijaniKiosk product-media resource.

The application should not receive unrestricted access to all storage resources in the cloud account.

---

## 6. Example Policy Structure

The following example uses AWS IAM policy syntax to demonstrate the least-privilege concept.

The resource names are illustrative and should be replaced with the actual production resource identifiers during deployment.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListProductMedia",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::kijaniosk-product-media",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "products/*"
          ]
        }
      }
    },
    {
      "Sid": "ManageProductMediaObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::kijaniosk-product-media/products/*"
    }
  ]
}
```

This example demonstrates an important distinction between bucket-level and object-level permissions.

The listing operation applies to the bucket resource, while object operations apply to objects within the designated product-media path.

---

## 7. Why These Permissions Are Required

### `s3:GetObject`

This permission allows the application to retrieve product-media objects.

It is required when the application needs to display or process stored product-media files.

### `s3:PutObject`

This permission allows the application to upload new product-media objects.

It is required when administrators or authorized application workflows add product media.

### `s3:DeleteObject`

This permission allows the application to remove product-media objects when they are intentionally deleted.

This permission should only be included if deletion is genuinely required by the application.

### `s3:ListBucket`

This permission allows the application to list objects within the designated storage path.

The policy limits the listing operation to the relevant `products/` prefix.

---

## 8. Permissions Intentionally Excluded

The role should not receive permissions that are unrelated to the defined application task.

Examples of permissions that should not be granted include:

```text
s3:*
iam:*
ec2:*
rds:*
cloudformation:*
AdministratorAccess
```

These permissions would provide capabilities far beyond the requirements of managing product-media objects.

The application should also not receive unrestricted access to every object-storage bucket in the account.

---

## 9. Resource-Level Restriction

The policy restricts object operations to:

```text
arn:aws:s3:::kijaniosk-product-media/products/*
```

This is preferable to granting access to every object in every storage resource.

Resource restrictions reduce the potential impact of:

* Application vulnerabilities.
* Compromised credentials.
* Configuration errors.
* Accidental deletion.
* Unauthorized application behavior.

Least privilege therefore applies not only to **what actions** an identity can perform, but also to **where those actions can be performed**.

---

## 10. Role-Based Access Instead of Long-Lived Credentials

The application should use an IAM role and temporary credentials where the cloud environment supports this mechanism.

Long-lived access keys should not be embedded in:

* Source code.
* Git repositories.
* Configuration files committed to version control.
* Container images.
* Public documentation.

A role-based approach reduces the risk associated with accidentally exposing permanent credentials.

---

## 11. Trust Relationship

An IAM role must have a trust relationship defining which principal is allowed to assume the role.

The exact trust policy depends on the compute service used to host KijaniKiosk.

Conceptually:

```text
Approved KijaniKiosk Compute Service
              │
              │ AssumeRole
              ▼
KijaniKioskProductMediaRole
              │
              ▼
Dedicated Product Media Storage
```

Only the intended application workload should be allowed to assume the role.

The trust relationship should therefore be reviewed separately from the permissions policy.

---

## 12. Separation of Permissions

The product-media role should not become a general-purpose application role.

If another KijaniKiosk component requires access to a different resource, it should receive permissions appropriate to that component's task.

For example:

```text
Application Component A
        │
        ▼
Product Media Role
        │
        ▼
Product Media Storage


Application Component B
        │
        ▼
Separate Role
        │
        ▼
Required Application Resource
```

This separation limits the impact of a compromised application component.

---

## 13. Environment Separation

Production, staging, and development environments should not unnecessarily share the same IAM role or storage resources.

A conceptual environment structure is:

```text
Development
    │
    └── Development IAM Role
            │
            └── Development Resources

Staging
    │
    └── Staging IAM Role
            │
            └── Staging Resources

Production
    │
    └── Production IAM Role
            │
            └── Production Resources
```

This reduces the risk of development workloads accidentally accessing production resources.

---

## 14. Security Benefits

The least-privilege approach provides several security benefits.

### Reduced Blast Radius

If the application or its credentials are compromised, the attacker's permissions are limited to the resources available to that role.

### Reduced Accidental Access

The application cannot intentionally or accidentally modify unrelated cloud resources when those permissions have not been granted.

### Improved Accountability

Separate roles make it easier to understand which application component is responsible for particular cloud actions.

### Easier Auditing

Narrowly defined permissions make IAM reviews and security audits easier.

---

## 15. Operational Considerations

IAM policies should be reviewed periodically.

The engineering team should ask:

* Are all permissions still required?
* Are any permissions unused?
* Can resource restrictions be made more specific?
* Has the application architecture changed?
* Are development and production permissions properly separated?
* Are credentials being managed securely?

Unused permissions should be removed rather than retained indefinitely.

---

## 16. Testing IAM Permissions

IAM permissions should be tested before production deployment.

Testing should verify that the application can perform its intended operations.

For example:

```text
Upload product image        → Allowed
Retrieve product image      → Allowed
Delete product image        → Allowed
List product media          → Allowed

Modify unrelated bucket     → Denied
Access IAM configuration    → Denied
Modify compute resources    → Denied
Access unrelated databases → Denied
```

The objective is to confirm both sides of least privilege:

1. Required actions work.
2. Unnecessary actions fail.

---

## 17. Infrastructure as Code

Where practical, IAM resources should be managed through Infrastructure as Code.

This provides:

* Version control.
* Reviewable changes.
* Repeatable deployments.
* Configuration consistency.
* Change history.
* Easier auditing.

IAM changes should follow the same controlled Git workflow used for other infrastructure changes.

A proposed IAM modification should therefore be reviewed before being applied to a production environment.

---

## 18. Relationship to DevOps

The IAM design supports the Flow, Feedback, and Learning principles described in `delivery-notes.md`.

### Flow

IAM configuration can be version-controlled and incorporated into repeatable deployment workflows.

### Feedback

Code review, policy validation, and security testing provide feedback before permissions are deployed.

### Learning

IAM reviews can identify excessive permissions and improve future security configurations.

This integrates security into the delivery process rather than treating security as a separate final-stage activity.

---

## 19. Future Security Improvements

As KijaniKiosk grows, additional security controls can be considered.

Potential improvements include:

* More granular IAM roles.
* Automated IAM policy validation.
* Centralized audit logging.
* Continuous security monitoring.
* Encryption controls.
* Resource-based policies where appropriate.
* Automated detection of unused permissions.
* Separation of duties for sensitive administrative operations.
* Stronger environment isolation.

These controls should be introduced according to actual risk and operational requirements.

---

## 20. IAM Decision Summary

| Area                   | KijaniKiosk Approach                    |
| ---------------------- | --------------------------------------- |
| Identity type          | Application IAM role                    |
| Primary principle      | Least privilege                         |
| Application task       | Manage product-media objects            |
| Storage scope          | Dedicated product-media resource        |
| Object permissions     | Read, write, delete                     |
| Listing permission     | Limited to required product prefix      |
| Administrative access  | Not granted                             |
| Long-lived credentials | Avoided                                 |
| Environment isolation  | Separate roles/resources recommended    |
| Policy management      | Version controlled and reviewed         |
| Validation             | Test both allowed and denied operations |

---

## 21. Conclusion

The KijaniKiosk IAM design applies least privilege by defining permissions around a specific application task rather than granting broad access to the cloud environment.

The proposed application role can manage only the product-media resources required by the application and does not receive unrelated administrative permissions.

Using role-based access, resource-level restrictions, environment separation, policy review, and permission testing reduces unnecessary access and limits the potential impact of a compromised application component.

The IAM design should evolve as the KijaniKiosk architecture grows, with permissions reviewed regularly and reduced whenever they are no longer required.

---

## 22. References

* Amazon Web Services. *IAM Best Practices*.
  https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

* Amazon Web Services. *IAM Policies and Permissions*.
  https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html

* Amazon Web Services. *AWS Well-Architected Framework — Security Pillar*.
  https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html

* National Institute of Standards and Technology. *Zero Trust Architecture (SP 800-207)*.
  https://doi.org/10.6028/NIST.SP.800-207
