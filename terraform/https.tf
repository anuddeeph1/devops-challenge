# HTTPS Configuration for ALB with Self-Signed Certificate

# Generate private key
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate self-signed certificate with ALB DNS name
resource "tls_self_signed_cert" "main" {
  private_key_pem = tls_private_key.main.private_key_pem

  subject {
    common_name  = aws_lb.main.dns_name  # Use ALB DNS as common name
    organization = "DevOps Challenge"
  }

  dns_names = [
    aws_lb.main.dns_name,  # Include ALB DNS in subject alternative names
    "simpletimeservice.local"
  ]

  validity_period_hours = 8760  # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Import certificate to ACM
resource "aws_acm_certificate" "self_signed" {
  private_key      = tls_private_key.main.private_key_pem
  certificate_body = tls_self_signed_cert.main.cert_pem

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-self-signed-cert"
      Type = "Self-Signed"
    }
  )
}

# HTTPS Listener (port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.self_signed.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = local.tags
}

# Output HTTPS URL
output "https_url" {
  description = "HTTPS URL (self-signed certificate - browser warning expected)"
  value       = "https://${aws_lb.main.dns_name}/"
}

output "https_curl_command" {
  description = "Curl command to test HTTPS (bypassing certificate validation)"
  value       = "curl -k https://${aws_lb.main.dns_name}/"
}

