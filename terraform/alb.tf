# Application Load Balancer Configuration

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTP from anywhere
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS from anywhere
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-alb-sg"
    }
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.tags,
    {
      Name = var.alb_name
    }
  )

  depends_on = [module.vpc]
}

# Target Group for EKS Nodes
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  # Health check configuration
  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    matcher             = "200"
  }

  # Deregistration delay
  deregistration_delay = 30

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-tg"
    }
  )

  depends_on = [aws_lb.main]
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = local.tags
}

# Get EKS worker node instances
data "aws_instances" "eks_nodes" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [module.eks.cluster_name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.eks]
}

# Register EKS nodes to ALB target group
resource "null_resource" "register_targets" {
  # Trigger on node changes
  triggers = {
    node_ids = join(",", data.aws_instances.eks_nodes.ids)
  }

  provisioner "local-exec" {
    command = <<-EOT
      export AWS_PROFILE=devtest
      for instance_id in ${join(" ", data.aws_instances.eks_nodes.ids)}; do
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.app.arn} \
          --targets Id=$instance_id,Port=30080 \
          --region ${var.aws_region} \
          --profile devtest
      done
    EOT
  }

  depends_on = [
    aws_lb_target_group.app,
    module.eks
  ]
}

# CloudWatch Log Group for ALB access logs (optional)
resource "aws_cloudwatch_log_group" "alb" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/alb/${var.alb_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-alb-logs"
    }
  )
}

