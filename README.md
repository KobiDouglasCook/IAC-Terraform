# Fuego Cloud Infrastructure

This repository contains the Terraform configuration and Kubernetes manifests for provisioning a scalable, production-ready EKS (Elastic Kubernetes Service) environment on AWS. It is modularized to promote reusability, security, and observability.

---

## 🚀 Overview

This infrastructure deploys a complete EKS-based Kubernetes cluster with the following features:

* **Modular Terraform Code**: Separated into modules (networking, EKS, DNS, node groups, CloudWatch)
* **Remote State Management**: Uses S3 and DynamoDB for backend state and locking
* **EKS Control Plane & Managed Node Groups**
* **Manual IAM Role Mapping** via `aws-auth`
* **Containerized Application Deployment**
* **Monitoring via CloudWatch Agent**
* **DNS with Route 53** pointing to Kubernetes load balancer
* **CI/CD with Github Actions** allowing for safe deployment and app integration

---

## 🧱 Folder Structure

```
.
├── bootstrap/                # S3 and DynamoDB backend setup
├── infrastructure/          # Main Terraform root module
├── k8s/                     # Kubernetes YAML manifests (e.g. app deployment, services)
├── modules/                 # Custom Terraform modules
│   ├── cloudwatch/
│   ├── compute/
│   ├── database/
│   ├── dns/
│   ├── eks/
│   ├── networking/
│   └── security/
└── .github/workflows/       # (For GitHub Actions workflows)
```

---

## 🔐 Backend Configuration

Terraform uses an S3 bucket and DynamoDB table for state and locking:

```hcl
backend "s3" {
  bucket         = "devops-kobi-tf-state"
  key            = "infra/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform_state_locking"
  encrypt        = true
}
```

---

## 🌐 Components

### 1. **Networking**

* Creates a VPC, public/private subnets, internet gateway, route tables

### 2. **EKS Cluster**

* Provisions the EKS control plane
* Enables IRSA and control plane logging

### 3. **Node Group (Manual Role)**

* IAM role for worker nodes is manually defined for greater control
* Role is mapped to `aws-auth` using a separate module

### 4. **AWS Auth**

* Maps IAM users and node group role to Kubernetes RBAC
* Allows specified IAM user to have `system:masters` access

### 5. **Kubernetes Resources**

* Application manifests deployed via Terraform
* Dynamically rendered YAML with variables

### 6. **Monitoring (CloudWatch)**

* CloudWatch Agent DaemonSet deployed for log and metric collection

### 7. **DNS (Route 53)**

* A CNAME record points to the EKS load balancer for external access

---

## ⚙️ Requirements

* Terraform 1.8+
* AWS CLI configured
* IAM user with full EKS, IAM, and S3/DynamoDB access

---

## 🛠️ Commands

```bash
# Setup backend (run from bootstrap/)
terraform init
terraform apply

# Provision infrastructure (run from infrastructure/)
terraform init
terraform apply
```

---

## 📦 CI/CD

CI/CD is implemented using GitHub Actions and supports the following workflows:

* **Pull Requests to `main`**:

  * Runs `terraform fmt`, `validate`, and `plan`

* **Merges to `main`**:

  * Executes `terraform apply` automatically

### 🧪 Workflow Files

Located in `.github/workflows/`:

* `terraform-plan.yml`: Runs on PRs
* `terraform-apply.yml`: Runs on push to `main`

Ensure that the repository has GitHub secrets set:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`

---

## 📘 Terraform Infrastructure Setup Script

This repository includes a fully automated Bash script (`deploy.sh`) that provisions AWS infrastructure using Terraform, sets up an EKS cluster, deploys Kubernetes manifests, and configures DNS with Route 53.

### 🔧 Prerequisites

Ensure the following tools are installed and configured:

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- AWS credentials configured via `aws configure` or assumed IAM role
- (Optional) Existing Route 53 hosted zone for DNS setup

### 📜 Script Overview

The `deploy.sh` script executes the following steps:

1. **Pre-flight Checks** – Validates that required tools are installed and AWS credentials are active.
2. **Backend Bootstrapping** – Initializes the Terraform backend (S3 + DynamoDB).
3. **EKS Provisioning** – Applies the Terraform module to create the EKS cluster.
4. **Kubeconfig Update** – Authenticates `kubectl` with the new EKS cluster.
5. **Kubernetes Deployment** – Applies Kubernetes manifests (Deployment + Service).
6. **Load Balancer Discovery** – Waits for ELB provisioning and extracts DNS hostname.
7. **Route 53 Configuration** – Writes DNS variables and applies Route 53 records via Terraform.
8. **Cleanup** – Deletes existing Kubernetes Deployment/Service (if any) to avoid recreation errors.
9. **Final Apply** – Applies all remaining Terraform infrastructure.

### ▶️ Usage

```bash
chmod +x deploy.sh
./deploy.sh
```
---

### 🧼 Teardown

```bash
# First destroy all infrastructure
cd infrastructure
terraform destroy -auto-approve

# Last destroy the backend resources
cd ../bootstrap
terraform destroy -auto-approve

```

---

## 📬 Contact

This infrastructure was built for `fuego-cloud` by Kobi Cook. Contributions, improvements, and questions are welcome!
