locals {
  cluster_name = var.cluster_name
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = var.tags
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # Cluster access configuration
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # VPC and networking
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # EKS Managed Node Group
  eks_managed_node_groups = {
    baseline-ondemand = {
      name = "baseline-ondemand"

      instance_types = var.node_instance_types
      capacity_type  = "SPOT"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Use Amazon Linux 2023
      ami_type = "AL2023_x86_64_STANDARD"

      labels = {
        role        = "general"
        environment = "demo"
      }

      tags = merge(
        var.tags,
        {
          Name = "${local.cluster_name}-node"
        }
      )
    }
  }

  tags = var.tags
}

################################################################################
# EBS CSI Driver IRSA (IAM Role for Service Account)
################################################################################

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

################################################################################
# ArgoCD Installation
################################################################################

resource "kubernetes_namespace" "argocd" {
  count = var.install_argocd ? 1 : 0

  metadata {
    name = "argocd"
  }

  depends_on = [module.eks]
}

# Generate random password for ArgoCD admin
resource "random_password" "argocd_admin" {
  count = var.install_argocd ? 1 : 0

  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store ArgoCD admin password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "argocd_admin" {
  count = var.install_argocd ? 1 : 0

  name_prefix             = "${local.cluster_name}-argocd-admin-"
  description             = "ArgoCD admin password for ${local.cluster_name}"
  recovery_window_in_days = var.argocd_secret_recovery_days

  tags = merge(
    var.tags,
    {
      Name = "${local.cluster_name}-argocd-admin-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "argocd_admin" {
  count = var.install_argocd ? 1 : 0

  secret_id = aws_secretsmanager_secret.argocd_admin[0].id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.argocd_admin[0].result
  })
}

resource "helm_release" "argocd" {
  count = var.install_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  namespace        = kubernetes_namespace.argocd[0].metadata[0].name
  create_namespace = false

  # Basic values
  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"  #  Protect argocd , don't expose it externally
        }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  # Set the admin password securely using set_sensitive
  set_sensitive {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(random_password.argocd_admin[0].result)
  }

  depends_on = [
    module.eks,
    kubernetes_namespace.argocd,
    aws_secretsmanager_secret_version.argocd_admin
  ]
}

