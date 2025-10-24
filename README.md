# GitOps EKS Setup - Notaben Assignment

Minimal, production-sensible GitOps setup on AWS with EKS, Terraform, Helm, and ArgoCD.

## Overview

This project provisions:
- **EKS Cluster** v1.31.x in `eu-central-1` (Frankfurt)
- **VPC** with public/private subnets across 3 availability zones
- **Managed Node Group** using SPOT instances for cost optimization
- **Helm Chart** for simple nginx application
- **ArgoCD** for GitOps continuous deployment

## Prerequisites

Ensure you have the following installed and configured:

1. **Terraform** >= 1.3
2. **AWS CLI** configured with credentials for `eu-central-1` region
3. **kubectl** for Kubernetes management
4. **Helm** (optional, for local testing)

### AWS Credentials & Permissions

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Ensure your IAM user/role has permissions for:
# - VPC, subnets
# - EKS clusters and node groups
# - IAM roles and policies
# - EC2 instances
# - Secrets Manager
```


## Quick Start

### Using Makefile (Recommended)

```bash
# 1. Initialize and deploy infrastructure
make init
make apply

# 2. Check cluster status
make status

# 3. Update argocd/application.yaml with your Git repo URL, then:
make deploy-app

# 4. Check deployment
make check-app
```

### Manual Deployment

#### 1. Deploy EKS Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review and apply (~15 minutes)
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region eu-central-1 --name notaben-eks-cluster

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

**Resources Created**: VPC with 6 subnets, NAT Gateway, EKS Cluster, Managed Node Group (SPOT), IAM roles, ArgoCD (via Helm)

#### 2. Get ArgoCD Password

ArgoCD password is stored in AWS Secrets Manager. Access it via AWS Console or CLI:

```bash
# Get secret name from Terraform outputs
cd terraform
terraform output -raw argocd_secret_name

# Retrieve password from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id <secret-name-from-above> \
  --query SecretString --output text | jq -r .password
```

#### 3. Deploy Application via GitOps

```bash
# Update Git repository URL in argocd/application.yaml
sed -i 's|YOUR-USERNAME/YOUR-REPO|your-github-username/your-repo-name|g' argocd/application.yaml

# Apply ArgoCD Application
kubectl apply -n argocd -f argocd/application.yaml

# Verify sync
kubectl get applications -n argocd

# Check workloads
kubectl get pods,svc -n nb-challenge
```

#### 4. Verify Deployment

```bash
# Port-forward to test application
kubectl port-forward svc/simple-app -n nb-challenge 8081:80

# Test
curl http://localhost:8081
```

## Cleanup

```bash
# Remove everything
make clean-all

# Or manually
kubectl delete -f argocd/application.yaml
cd terraform && terraform destroy
```

## Assumptions & Trade-offs

**Cost Optimization:**
- SPOT instances (~70% cheaper but may be interrupted with 2-min notice)
- Single NAT Gateway (use multiple for production)

**Security:**
- ArgoCD password stored in AWS Secrets Manager (KMS encrypted)
- Password passed via `set_sensitive` (never in values files or Helm history)
- 0-day secret recovery window for demo (set 7-30 days for production via `argocd_secret_recovery_days` variable)
- Public EKS API access (restrict via security groups for production)

**Simplifications:**
- No ingress controller or TLS certificates
- No monitoring/logging setup
- No network policies or pod security standards
- Manual Git repository URL configuration required

**Production Improvements Needed:**
- Ingress controller (nginx-ingress or AWS ALB)
- TLS certificates (cert-manager)
- Monitoring (Prometheus + Grafana, CloudWatch)
- Logging (Fluent Bit + CloudWatch)
- Multiple NAT Gateways for HA
- Remote Terraform state (S3)

## Project Structure

```
notaben_assignment/
├── Makefile                 # All commands organized for easy use
├── README.md                # This file
├── terraform/               # EKS infrastructure
│   ├── main.tf              # VPC, EKS, ArgoCD
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   └── versions.tf          # Provider versions
├── helm-chart/simple-app/   # Application Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── argocd/
    └── application.yaml     # ArgoCD Application manifest
```

## Useful Commands

```bash
# Makefile commands
make help              # Show all available commands
make init              # Initialize Terraform
make apply             # Deploy infrastructure
make status            # Show cluster status
make argocd-ui         # Access ArgoCD UI (https://localhost:8080)
make deploy-app        # Deploy application via ArgoCD
make check-app         # Check application status
make app-ui            # Access application (http://localhost:8081)
make clean-all         # Remove everything

# Direct kubectl commands
kubectl get nodes
kubectl get pods -n nb-challenge
kubectl get applications -n argocd
kubectl logs -n nb-challenge <pod-name>
```