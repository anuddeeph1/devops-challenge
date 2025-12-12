# Terraform Variable Values for SimpleTimeService - DEVELOPMENT/COST-OPTIMIZED
# This file contains cost-optimized values for development and testing
# Use this with: terraform apply -var-file=terraform-dev.tfvars

# General Configuration
aws_region   = "us-west-1"
project_name = "simpletimeservice"
environment  = "development"
owner        = "devops-team"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Cost Optimization: Use single NAT gateway (saves ~$33/month)
single_nat_gateway = true

# EKS Configuration
kubernetes_version  = "1.33"
node_instance_types = ["t3a.medium"] # AMD instances are ~10% cheaper

# Cost Optimization: Use Spot instances (saves ~60% on compute)
# WARNING: Spot instances can be terminated by AWS with 2-minute notice
node_capacity_type = "SPOT"

# Node Group Sizing - Minimal for development
node_min_size     = 1
node_max_size     = 2
node_desired_size = 1

# Application Configuration - Minimal replicas
kubernetes_namespace = "simpletimeservice"
app_image_repository = "anuddeeph1/simpletimeservice"
app_image_tag        = "latest"
app_replica_count    = 3 # Single replica for cost savings

# Load Balancer Configuration
alb_name     = "simpletimeservice-alb-dev"
alb_internal = false

# Health Check Configuration
health_check_path                = "/health"
health_check_interval            = 30
health_check_timeout             = 5
health_check_healthy_threshold   = 2
health_check_unhealthy_threshold = 3

# Auto Scaling Configuration
enable_cluster_autoscaler = false # Disable for dev to save on additional pods
enable_metrics_server     = true

# Monitoring Configuration
enable_cloudwatch_logs = true
log_retention_days     = 3 # Reduced retention for cost savings

# Additional Tags
additional_tags = {
  CostCenter    = "Engineering"
  Team          = "DevOps"
  Environment   = "Development"
  CostOptimized = "true"
}

