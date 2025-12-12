# HTTPS Setup Guide

How to secure your SimpleTimeService with SSL/TLS (HTTPS).

## Current Status

**Current URL**: `http://test-cluster-alb-1326148463.us-west-1.elb.amazonaws.com/`  
**Protocol**: HTTP (insecure) ⚠️

## Why Add HTTPS?

- ✅ Encrypted traffic
- ✅ Browser security indicators
- ✅ SEO benefits
- ✅ Compliance requirements
- ✅ Professional appearance

---

## Option 1: ACM Certificate with Custom Domain (Recommended)

### Prerequisites
- Custom domain name (e.g., `example.com`)
- Route53 hosted zone or access to DNS provider

### Steps

#### 1. Update `terraform/variables.tf`

Add these variables:

```hcl
variable "domain_name" {
  description = "Custom domain name for the application"
  type        = string
  default     = "simpletimeservice.yourdomain.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation"
  type        = string
  default     = ""
}
```

#### 2. Update `terraform/terraform.tfvars`

```hcl
domain_name = "simpletimeservice.example.com"
route53_zone_id = "Z1234567890ABC"  # Your hosted zone ID
```

#### 3. Uncomment Option 1 in `terraform/ssl.tf`

Find and uncomment the section marked "Option 1".

#### 4. Apply Changes

```bash
export AWS_PROFILE=devtest
cd terraform
terraform apply
```

#### 5. Access Your Secure Application

```bash
https://simpletimeservice.example.com/
```

### Cost

**ACM Certificate**: FREE (AWS-managed certificates are free)  
**No additional cost!**

---

## Option 2: Self-Signed Certificate (Testing Only)

### When to Use
- Quick testing
- Internal applications
- Don't have a domain name yet

### Steps

#### 1. Uncomment Option 2 in `terraform/ssl.tf`

#### 2. Apply Changes

```bash
export AWS_PROFILE=devtest
cd terraform
terraform apply
```

#### 3. Access Application

```bash
https://test-cluster-alb-1326148463.us-west-1.elb.amazonaws.com/
```

**Note**: Browser will show security warning - click "Advanced" → "Proceed anyway"

### Cost

**Self-signed certificate**: FREE  
**Stored in ACM**: FREE

---

## Option 3: Let's Encrypt (External Tool)

Use cert-manager with Let's Encrypt for free certificates:

### Steps

#### 1. Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

#### 2. Create ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

#### 3. Use with Ingress

This requires switching from ALB to NGINX Ingress Controller.

---

## Quick Setup: Self-Signed for Demo

If you want HTTPS quickly for demo purposes:

<function_calls>
<invoke name="run_terminal_cmd">
<parameter name="command">export AWS_PROFILE=devtest && cd /Users/anudeepnalla/Downloads/particle-41/devops-challenge-solution && echo "🔐 Quick HTTPS Setup Script" && echo "" && echo "To add self-signed HTTPS:" && echo "" && echo "1. Edit terraform/ssl.tf" && echo "2. Uncomment 'Option 2' section (lines ~90-160)" && echo "3. Run: terraform apply" && echo "4. Access: https://test-cluster-alb-1326148463.us-west-1.elb.amazonaws.com/" && echo "" && echo "Note: Browser will show warning (expected for self-signed)"
