################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

################################################################################
# EKS Cluster Outputs
################################################################################

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

################################################################################
# Region Output
################################################################################

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

################################################################################
# Kubeconfig Command
################################################################################

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

################################################################################
# ArgoCD Outputs
################################################################################

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.install_argocd ? kubernetes_namespace.argocd[0].metadata[0].name : "ArgoCD not installed"
}

output "argocd_server_url" {
  description = "Command to access ArgoCD UI via port-forward"
  value       = var.install_argocd ? "kubectl port-forward svc/argocd-server -n argocd 8080:443" : "ArgoCD not installed"
}

output "argocd_secret_name" {
  description = "AWS Secrets Manager secret name for ArgoCD admin password"
  value       = var.install_argocd ? aws_secretsmanager_secret.argocd_admin[0].name : "ArgoCD not installed"
}

output "argocd_password_command" {
  description = "Command to retrieve ArgoCD admin password from AWS Secrets Manager"
  value       = var.install_argocd ? "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.argocd_admin[0].name} --query SecretString --output text | jq -r .password" : "ArgoCD not installed"
}
