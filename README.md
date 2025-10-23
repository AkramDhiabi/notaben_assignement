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