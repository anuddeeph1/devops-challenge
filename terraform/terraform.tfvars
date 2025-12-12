# Terraform Variable Values for SimpleTimeService
# This file contains default values that can be overridden

# General Configuration
aws_region   = "us-west-1"
project_name = "test-cluster"
environment  = "production"
owner        = "devops-team"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Use 1 NAT gateway for cost savings (set to false for production HA)
single_nat_gateway = true #false for HA

# EKS Configuration
kubernetes_version  = "1.33"
node_instance_types = ["t3a.medium"]
node_capacity_type  = "ON_DEMAND"

# Node Group Sizing
node_min_size     = 1
node_max_size     = 2
node_desired_size = 1

# Application Configuration
kubernetes_namespace = "simpletimeservice"
app_image_repository = "anuddeeph1/simpletimeservice"
app_image_tag        = "latest"
app_replica_count    = 3

# Load Balancer Configuration
alb_name     = "test-cluster-alb"
alb_internal = false

# Health Check Configuration
health_check_path                = "/health"
health_check_interval            = 30
health_check_timeout             = 5
health_check_healthy_threshold   = 2
health_check_unhealthy_threshold = 3

# Auto Scaling Configuration
enable_cluster_autoscaler = true
enable_metrics_server     = true

# Monitoring Configuration
enable_cloudwatch_logs = true
log_retention_days     = 7

# Additional Tags
additional_tags = {
  CostCenter = "Engineering"
  Team       = "DevOps"
}

