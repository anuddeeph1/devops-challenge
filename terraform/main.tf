# Main Terraform configuration for SimpleTimeService infrastructure

# Terraform version and provider configuration is in versions.tf

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables
locals {
  cluster_name = "${var.project_name}-cluster"

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  single_nat_gateway   = var.single_nat_gateway

  # Tags for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = local.tags
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"  # Upgraded to support authentication_mode

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  # Disable KMS encryption for simpler permissions (not needed for demo)
  create_kms_key            = false
  cluster_encryption_config = {}

  # Enable API authentication mode for easier cluster access
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # VPC and Subnets - EKS Control Plane in private subnets
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      name = "main-ng" # Shortened to avoid IAM role name length limit

      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Launch template configuration
      disk_size = 50

      # Use private subnets for worker nodes
      subnet_ids = module.vpc.private_subnets

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      # Attach additional IAM policies for EBS CSI driver
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      tags = merge(
        local.tags,
        {
          Name = "${var.project_name}-node"
        }
      )
    }
  }

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "Cluster to node all ports/protocols"
      protocol                   = "-1"
      from_port                  = 0
      to_port                    = 0
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }

    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress_alb_to_nodes = {
      description              = "ALB to nodes"
      protocol                 = "tcp"
      from_port                = 30000
      to_port                  = 32767
      type                     = "ingress"
      source_security_group_id = aws_security_group.alb.id
    }
  }

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  tags = local.tags
}

# Kubernetes Provider Configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region,
      "--profile",
      "devtest"
    ]
  }
}

# Helm Provider Configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region,
        "--profile",
        "devtest"
      ]
    }
  }
}

# Create namespace for application
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.kubernetes_namespace

    labels = {
      name        = var.kubernetes_namespace
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}

# Deploy application using Helm chart
resource "helm_release" "simpletimeservice" {
  name       = "simpletimeservice"
  namespace  = kubernetes_namespace.app.metadata[0].name
  chart      = "../kubernetes/helm-chart"
  
  set {
    name  = "image.repository"
    value = var.app_image_repository
  }

  set {
    name  = "image.tag"
    value = var.app_image_tag
  }

  set {
    name  = "replicaCount"
    value = var.app_replica_count
  }

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "service.nodePort"
    value = "30080"
  }

  depends_on = [
    kubernetes_namespace.app,
    aws_lb.main
  ]
}

# Alternative: Deploy via kubectl manifests (commented out)
# You can use kubectl apply -f kubernetes/ if you prefer
/*
resource "kubernetes_deployment_v1" "simpletimeservice" {
  metadata {
    name      = "simpletimeservice"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "simpletimeservice"
    }
  }

  spec {
    replicas = var.app_replica_count

    selector {
      match_labels = {
        app = "simpletimeservice"
      }
    }

    template {
      metadata {
        labels = {
          app = "simpletimeservice"
        }
      }

      spec {
        service_account_name = "simpletimeservice"
        
        security_context {
          run_as_non_root = true
          run_as_user     = 65532
          run_as_group    = 65532
          fs_group        = 65532
        }

        container {
          name  = "simpletimeservice"
          image = "${var.app_image_repository}:${var.app_image_tag}"
          
          port {
            container_port = 8080
            name           = "http"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 65532
            
            capabilities {
              drop = ["ALL"]
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.app]
}

resource "kubernetes_service_v1" "simpletimeservice" {
  metadata {
    name      = "simpletimeservice"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    type = "NodePort"
    
    selector = {
      app = "simpletimeservice"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
      node_port   = 30080
    }
  }

  depends_on = [kubernetes_deployment_v1.simpletimeservice]
}
*/

# Wait for EKS cluster to be ready
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "export AWS_PROFILE=devtest && aws eks wait cluster-active --name ${module.eks.cluster_name} --region ${var.aws_region} --profile devtest"
  }

  depends_on = [module.eks]
}

