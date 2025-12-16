# 📘 Production-Grade 3-Tier Architecture on AWS using Terraform
### (DevOps End-to-End Reference Documentation)

Author: Thangavijay  
Purpose: Long-term reference for DevOps best practices  
Scope: Architecture, IaC, Security, Troubleshooting, CI/CD  

---

## 1. PROJECT OVERVIEW

### Goal
Design, deploy, validate, and destroy a **scalable, secure 3-tier web application** on AWS using **Terraform**, following **real-world DevOps best practices**.

This project intentionally covers:
- Infrastructure provisioning
- Security hardening
- Environment separation (dev/prod)
- Terraform remote state
- CI/CD with IAM role-based execution
- Real failure scenarios and fixes

---

## 2. 3-TIER ARCHITECTURE EXPLAINED

### What is a 3-Tier Architecture?

A 3-tier architecture separates concerns into **three logical layers**:

1. **Presentation Tier**
2. **Application Tier**
3. **Data Tier**

This separation provides:
- Scalability
- Security isolation
- Independent failure handling
- Easier maintenance

---

### AWS Mapping of the 3 Tiers

| Tier | AWS Services Used |
|---|---|
| Presentation | ALB (Application Load Balancer) |
| Application | EC2 + Auto Scaling Group |
| Data | Amazon RDS |
| Shared | VPC, Subnets, IAM, Security Groups |

---

### High-Level Flow

```

Internet
↓
Application Load Balancer (Public Subnets)
↓
Auto Scaling Group (Private Subnets)
↓
Amazon RDS (Private Isolated Subnets)

```

Only the ALB is publicly accessible.

---

## 3. NETWORK ARCHITECTURE (VPC DESIGN)

### CIDR Layout

```

VPC: 10.0.0.0/16

Public Subnets (ALB)

* 10.0.1.0/24
* 10.0.2.0/24

Private App Subnets (EC2)

* 10.0.11.0/24
* 10.0.12.0/24

Private DB Subnets (RDS)

* 10.0.21.0/24
* 10.0.22.0/24

```

### Why this design?
- ALB must be public
- EC2 must never be public
- RDS must be isolated
- NAT Gateway provides outbound access only

---

## 4. SECURITY MODEL (CRITICAL)

### Security Groups (Zero Trust Model)

| Source | Destination | Port |
|---|---|---|
| Internet | ALB | 80 / 443 |
| ALB | EC2 | 80 |
| EC2 | RDS | 3306 |
| Internet | EC2 | ❌ |
| Internet | RDS | ❌ |

Security groups reference **other security groups**, not CIDR blocks.

---

### IAM Best Practices

- No access keys on EC2
- IAM Role attached to EC2
- Permissions:
  - SSM access
  - Secrets Manager read
  - CloudWatch logging

---

### Secrets Management

- DB credentials stored in **AWS Secrets Manager**
- Terraform never hardcodes passwords
- App fetches secrets at runtime

---

## 5. TERRAFORM STRUCTURE (ENTERPRISE STANDARD)

```

.
├── environments
│   └── prod
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── modules
│   ├── vpc
│   ├── security-groups
│   ├── alb
│   ├── asg
│   ├── rds
│   └── s3
├── providers.tf
├── versions.tf

````

---

## 6. ENVIRONMENT SEPARATION STRATEGY

### Why separate environments?
- Safe testing
- Independent state
- CI/CD promotion
- Reduced blast radius

### How it’s done
- Separate folders (`dev`, `prod`)
- Separate `terraform.tfvars`
- Separate S3 state paths
- Same reusable modules

---

## 7. TERRAFORM REMOTE STATE (S3 BACKEND)

### Why remote state?
- Team collaboration
- CI/CD execution
- State locking
- Prevent corruption

### Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket = "three-tier-practice"
    key    = "prod/terraform.tfstate"
    region = "ap-south-1"
  }
}
````

### Important Behavior

* `terraform init` does NOT create state
* State is created ONLY after `terraform apply`

---

## 8. COMMON ISSUES FACED & SOLUTIONS

### Issue 1: Variable not declared

**Error**

```
Reference to undeclared input variable
```

**Cause**

* `variables.tf` missing in environment folder

**Fix**

* Declare all root variables explicitly

---

### Issue 2: Terraform asking for region

**Cause**

* Terraform run from wrong directory
* `terraform.tfvars` not loaded

**Fix**

```bash
cd environments/prod
terraform plan
```

---

### Issue 3: UnauthorizedOperation (DescribeImages)

**Cause**

* IAM user had only S3 permissions

**Fix**

* Attach EC2 read permissions
* Or use PowerUserAccess (dev)

---

### Issue 4: State not stored in S3

**Cause**

* `backend.tf` placed in repo root

**Fix**

* Move `backend.tf` into environment folder
* Re-run `terraform init -migrate-state`

---

### Issue 5: terraform state list → No state file found

**Cause**

* No `terraform apply` executed yet

**Fix**

* Run `terraform apply`
* State is created only after apply

---

### Issue 6: Destroy failures

#### a) RDS final snapshot error

```
final_snapshot_identifier is required
```

**Fix (dev)**

```hcl
skip_final_snapshot = true
```

---

#### b) ALB deletion protection

```
Deletion protection is enabled
```

**Fix**

* Make deletion protection environment-based

---

#### c) IGW dependency violation

```
Network has mapped public addresses
```

**Fix**

* NAT Gateway must be destroyed before IGW
* Add explicit dependency

---

## 9. HOW TO TEST THE ENTIRE SYSTEM

### Infrastructure Validation

```bash
terraform state list
```

---

### Application Test

```bash
curl http://<ALB_DNS_NAME>
```

Expected:

```
Three Tier App - App Server
Healthy
```

---

### Target Group

* Targets must be **Healthy**

---

### Auto Scaling Test

* Increase desired capacity
* Confirm new EC2 launches
* Confirm target registration

---

### RDS Test

* Use SSM to access EC2
* Fetch secrets from Secrets Manager
* Connect to DB

---

### Security Audit

* No public EC2
* No public RDS
* S3 block public access enabled

---

## 10. CI/CD FOR TERRAFORM (BEST PRACTICE)

### Why CI/CD for Terraform?

* Consistency
* No human credentials
* Audit trail
* Safe changes

---

### Core Concept: IAM Role-Based Terraform

```
GitHub Actions
   ↓ (OIDC)
IAM Role (TerraformExecutionRole)
   ↓
AWS APIs
```

No IAM users. No access keys.

---

### IAM Trust Policy (GitHub → AWS)

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity"
}
```

---

### GitHub Actions Workflow

```yaml
name: Terraform CI

on:
  pull_request:
  push:
    branches: [ "main" ]

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/TerraformExecutionRole
          aws-region: ap-south-1

      - uses: hashicorp/setup-terraform@v3

      - run: terraform init
        working-directory: environments/prod

      - run: terraform validate
        working-directory: environments/prod

      - run: terraform plan
        working-directory: environments/prod
```

---

## 11. PRODUCTION SAFETY CONTROLS

| Control             | Purpose                           |
| ------------------- | --------------------------------- |
| Deletion Protection | Prevent accidental deletion       |
| Final Snapshots     | Protect DB data                   |
| DynamoDB Lock       | Prevent concurrent Terraform runs |
| IAM Roles           | Eliminate static credentials      |

---

## 12. FINAL TAKEAWAYS (IMPORTANT)

* Terraform does not guess — everything is explicit
* Destroy failures are safety features, not bugs
* Backend config is directory-scoped
* State is created only after apply
* CI/CD + IAM roles is the gold standard
* This architecture is interview-ready and production-ready

---

## 13. NEXT EVOLUTION (OPTIONAL)

* CloudWatch alarms
* WAF on ALB
* Blue/Green deployments
* ECS or EKS migration
* Policy-as-code (OPA / tfsec)
* Multi-region DR

---

## ✅ END OF DOCUMENT

```

