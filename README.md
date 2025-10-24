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

Required tools:

1. **Terraform** >= 1.3
2. **AWS CLI** configured with credentials for `eu-central-1` region
3. **kubectl** for Kubernetes management
4. **Helm** (optional, for local testing)

### AWS Credentials & Permissions

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Required IAM permissions:
# - VPC, subnets
# - EKS clusters and node groups
# - IAM roles and policies
# - EC2 instances
```


## Quick Start

### Using Makefile (Recommended)

```bash
# 1. Initialize and deploy infrastructure
make init
make apply

# 2. Check cluster status
make status

# 3. Get ArgoCD password
make argocd-password

# 4. Deploy application via GitOps
make deploy-app

# 5. Check deployment
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

ArgoCD stores its initial admin password in a Kubernetes secret. Retrieve it using:

```bash
# Get password using Makefile
make argocd-password

# Or directly with kubectl
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

#### 3. Deploy Application via GitOps

```bash
# Apply ArgoCD Application
kubectl apply -n argocd -f argocd/application.yaml

# Verify sync
kubectl get applications -n argocd

# Check workloads
kubectl get pods,svc -n nb-challenge
```

**Note:** The Git repository URL is already configured in `argocd/application.yaml` to point to `https://github.com/AkramDhiabi/notaben_assignement.git`.

#### 4. Verify Deployment

```bash
# Port-forward to test application
kubectl port-forward svc/simple-app -n nb-challenge 8081:80

# In another terminal, test the application
curl http://localhost:8081
```

## Local Testing with Kind

Test the complete GitOps workflow locally using Kind (Kubernetes in Docker). Only Docker is required.

### Setup

```bash
# Start local cluster with ArgoCD and app
make local-test
```

This script will:
1. Download Kind/kubectl if needed
2. Create Kind cluster
3. Install ArgoCD
4. Deploy app via ArgoCD from GitHub

### Access Services

```bash
# Get ArgoCD password
make local-argocd-password

# Port-forward ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Visit: https://localhost:8080 (admin / password from above)

# Port-forward app
kubectl port-forward -n nb-challenge svc/simple-app 8081:80
# Visit: http://localhost:8081
```

### Check Status

```bash
# Check cluster status
make local-status

# Check ArgoCD application
kubectl get application simple-app -n argocd
```

### Cleanup

```bash
# Delete local cluster
make local-clean
```

## Cleanup

```bash
# Remove everything (application + infrastructure)
make clean-all
```

## Assumptions & Trade-offs

**Cost Optimization:**
- SPOT instances (~70% cheaper but may be interrupted with 2-min notice)
- Single NAT Gateway (use multiple for production)

**Security:**
- ArgoCD uses default initial admin password stored in Kubernetes secret
- For production: generate random password, store in AWS Secrets Manager (KMS encrypted), and inject via Helm `set_sensitive` to avoid exposure in values files or Helm history
- Public EKS API access (restrict via security groups for production)

**Simplifications:**
- No ingress controller or TLS certificates
- No monitoring/logging setup
- No network policies or pod security standards
- Port-forward access only (no LoadBalancer services)

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
├── README.md                # Main readme file
├── terraform/               # EKS infrastructure
│   ├── main.tf              # VPC, EKS, ArgoCD
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   └── versions.tf          # Provider versions
├── helm-chart/simple-app/   # Application Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── argocd/
│   └── application.yaml     # ArgoCD Application manifest
└── local-test/              # Local testing with Kind
    ├── setup.sh
    └── cleanup.sh
```

## Useful Commands

```bash
# Makefile commands (recommended)
make help              # Show all available commands

# AWS EKS
make init              # Initialize Terraform
make apply             # Deploy infrastructure
make configure-kubectl # Configure kubectl for EKS cluster
make status            # Show cluster status
make argocd-password   # Get ArgoCD admin password
make argocd-ui         # Access ArgoCD UI (https://localhost:8080)
make deploy-app        # Deploy application via ArgoCD
make check-app         # Check application status
make app-ui            # Access application (http://localhost:8081)
make clean             # Remove application only
make clean-all         # Remove everything (app + infrastructure)

# Local testing with Kind
make local-test              # Setup local cluster
make local-status            # Check local cluster
make local-argocd-password   # Get local ArgoCD password
make local-clean             # Delete local cluster

# Direct kubectl commands (if needed)
kubectl get nodes
kubectl get pods -n nb-challenge
kubectl get applications -n argocd
kubectl logs -n nb-challenge <pod-name>
```