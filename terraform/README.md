# Terraform Infrastructure for SimpleTimeService

This directory contains Terraform configuration to deploy a production-ready EKS cluster on AWS with Application Load Balancer.

## Architecture

- **VPC**: Custom VPC with 2 public and 2 private subnets across 2 availability zones in us-west-1
- **EKS Cluster**: Kubernetes 1.28 cluster with managed node groups in private subnets
- **Worker Nodes**: t3.medium instances with auto-scaling (2-4 nodes)
- **Load Balancer**: Application Load Balancer in public subnets
- **Remote State**: S3 bucket with DynamoDB locking for state management
- **Security**: Security groups, IAM roles, and network policies

## Prerequisites

1. **AWS CLI** configured with credentials
2. **Terraform** 1.6.0 or higher
3. **kubectl** for Kubernetes management
4. **AWS Account** with appropriate permissions

## AWS Credentials Setup

### Option 1: AWS CLI Configuration (Recommended)

```bash
# Configure AWS CLI
aws configure

# Provide:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-west-1
# - Default output format: json
```

### Option 2: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-1"
```

### Option 3: AWS SSO

```bash
# Configure SSO
aws sso login --profile your-profile

# Use profile
export AWS_PROFILE=your-profile
```

## Required IAM Permissions

Your AWS user/role needs the following permissions:
- EC2 (VPC, Subnets, Security Groups, NAT Gateway)
- EKS (Cluster, Node Groups)
- IAM (Roles, Policies)
- ELB (Application Load Balancer, Target Groups)
- S3 (State bucket)
- DynamoDB (Lock table)
- CloudWatch (Logs)

## Deployment Instructions

### Step 1: Clone Repository

```bash
git clone <your-repo-url>
cd devops-challenge-solution/terraform
```

### Step 2: Configure Variables

Edit `terraform.tfvars` to customize your deployment:

```hcl
# Update with your Docker Hub username
app_image_repository = "anuddeeph1/simpletimeservice"
app_image_tag        = "latest"

# Adjust for cost optimization
single_nat_gateway = true  # Use single NAT gateway to save costs

# Adjust node sizing
node_instance_types = ["t3.medium"]
node_desired_size   = 2
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform and download providers
terraform init

# This will create:
# - .terraform/ directory
# - .terraform.lock.hcl file
```

### Step 4: Review Plan

```bash
# Review what will be created
terraform plan

# Save plan to file
terraform plan -out=tfplan
```

Expected resources to be created:
- ~60+ resources including VPC, EKS, ALB, Security Groups, IAM Roles

### Step 5: Apply Configuration

```bash
# Apply the plan
terraform apply

# Or apply saved plan
terraform apply tfplan

# Type 'yes' when prompted
```

**Note**: Initial deployment takes ~15-20 minutes for EKS cluster creation.

### Step 6: Configure kubectl

```bash
# Update kubeconfig to access cluster
aws eks update-kubeconfig \
  --name simpletimeservice-cluster \
  --region us-west-1

# Verify cluster access
kubectl get nodes

# Check application deployment
kubectl get pods -n simpletimeservice
kubectl get svc -n simpletimeservice
```

### Step 7: Get Application URL

```bash
# Get load balancer DNS name
terraform output alb_dns_name

# Test the application
curl http://$(terraform output -raw alb_dns_name)/

# Test health endpoint
curl http://$(terraform output -raw alb_dns_name)/health
```

### Step 8: Enable Remote State (Optional)

After initial deployment, enable remote state:

```bash
# Get backend configuration
terraform output backend_config

# Uncomment backend block in backend.tf
# Update with your account ID

# Migrate state to S3
terraform init -migrate-state

# Type 'yes' when prompted
```

## Remote State Backend

The configuration automatically creates:
- S3 bucket for state storage with versioning and encryption
- DynamoDB table for state locking
- Lifecycle policies for old version cleanup

### Backend Configuration

After initial apply, update `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "simpletimeservice-terraform-state-<YOUR-ACCOUNT-ID>"
    key            = "prod/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "simpletimeservice-terraform-locks"
    encrypt        = true
  }
}
```

Then migrate:

```bash
terraform init -migrate-state
```

## Terraform Commands

### Plan and Apply

```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Auto-approve (use with caution)
terraform apply -auto-approve

# Target specific resource
terraform apply -target=module.eks
```

### Outputs

```bash
# Show all outputs
terraform output

# Show specific output
terraform output alb_dns_name

# Output in JSON format
terraform output -json
```

### State Management

```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show aws_lb.main

# Refresh state
terraform refresh
```

### Destroy Resources

```bash
# Destroy all resources
terraform destroy

# Type 'yes' when prompted

# Target specific resource
terraform destroy -target=module.eks
```

**Warning**: This will delete all infrastructure. Data loss may occur.

## Module Structure

```
terraform/
├── main.tf              # Main configuration with VPC and EKS modules
├── variables.tf         # Input variable definitions
├── terraform.tfvars     # Variable values
├── outputs.tf           # Output definitions
├── backend.tf           # Remote state configuration
├── versions.tf          # Provider version constraints
├── alb.tf              # Application Load Balancer
├── iam.tf              # IAM roles and policies
└── README.md           # This file
```

## Resource Costs (Estimated)

### Monthly Costs in us-west-1 (approximate):

| Resource | Cost |
|----------|------|
| EKS Control Plane | $73/month |
| t3.medium nodes (2x) | ~$60/month |
| NAT Gateway (2x) | ~$65/month |
| Application Load Balancer | ~$23/month |
| EBS volumes | ~$8/month |
| Data transfer | Variable |
| **Total** | **~$229/month** |

### Cost Optimization:

```hcl
# Use single NAT gateway
single_nat_gateway = true  # Saves ~$32/month

# Use smaller instances
node_instance_types = ["t3.small"]  # Saves ~$30/month

# Reduce node count
node_desired_size = 1  # Saves ~$30/month (not recommended for production)

# Use Spot instances
node_capacity_type = "SPOT"  # Saves ~60% on compute
```

## Networking

### VPC Configuration

- **CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (us-west-1a, us-west-1b)
- **Private Subnets**: 10.0.11.0/24, 10.0.12.0/24 (us-west-1a, us-west-1b)

### Security Groups

#### ALB Security Group
- Ingress: 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0
- Egress: All traffic

#### EKS Node Security Group
- Ingress: All from ALB security group
- Ingress: NodePort range (30000-32767) from ALB
- Ingress: All from self
- Egress: All traffic

## Troubleshooting

### Cluster Creation Failed

```bash
# Check CloudWatch logs
aws logs tail /aws/eks/simpletimeservice-cluster/cluster --follow

# Check EKS cluster status
aws eks describe-cluster --name simpletimeservice-cluster --region us-west-1
```

### Cannot Connect to Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name simpletimeservice-cluster --region us-west-1

# Verify AWS credentials
aws sts get-caller-identity

# Check cluster endpoint
terraform output cluster_endpoint
```

### Nodes Not Ready

```bash
# Check node status
kubectl get nodes

# Describe node for details
kubectl describe node <node-name>

# Check node logs
kubectl logs -n kube-system -l app=aws-node
```

### Load Balancer Not Working

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check ALB listeners
aws elbv2 describe-listeners \
  --load-balancer-arn $(terraform output -raw alb_arn)

# Check security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id)
```

### Terraform State Lock

```bash
# If state is locked, force unlock (use with caution)
terraform force-unlock <lock-id>

# Check DynamoDB for locks
aws dynamodb scan \
  --table-name simpletimeservice-terraform-locks \
  --region us-west-1
```

### Permission Denied Errors

```bash
# Check IAM permissions
aws iam get-user

# Verify you have required policies attached
aws iam list-attached-user-policies --user-name <your-username>
```

## Cleanup

### Option 1: Terraform Destroy

```bash
# Destroy all resources
terraform destroy

# Type 'yes' when prompted
```

### Option 2: Manual Cleanup

If terraform destroy fails:

```bash
# Delete EKS cluster
aws eks delete-cluster --name simpletimeservice-cluster --region us-west-1

# Delete node group
aws eks delete-nodegroup \
  --cluster-name simpletimeservice-cluster \
  --nodegroup-name simpletimeservice-node-group \
  --region us-west-1

# Wait for deletion, then destroy remaining resources
terraform destroy
```

### Clean Up State Backend

```bash
# Delete S3 bucket (must be empty)
aws s3 rm s3://simpletimeservice-terraform-state-<ACCOUNT-ID> --recursive
aws s3 rb s3://simpletimeservice-terraform-state-<ACCOUNT-ID>

# Delete DynamoDB table
aws dynamodb delete-table \
  --table-name simpletimeservice-terraform-locks \
  --region us-west-1
```

## Advanced Features

### Enable Cluster Autoscaler

```hcl
enable_cluster_autoscaler = true
```

Cluster Autoscaler will automatically adjust node count based on pod resource requests.

### Enable Metrics Server

```hcl
enable_metrics_server = true
```

Required for Horizontal Pod Autoscaler (HPA).

### Multi-Environment Deployment

```bash
# Create workspace for staging
terraform workspace new staging

# Deploy staging environment
terraform apply -var-file=staging.tfvars

# Switch to production
terraform workspace select production
```

## Security Best Practices

- ✅ EKS nodes in private subnets
- ✅ Security groups with least privilege
- ✅ IAM roles with minimal permissions (IRSA)
- ✅ Encrypted S3 bucket for state
- ✅ State locking with DynamoDB
- ✅ Private EKS API endpoint (configurable)
- ✅ Network policies (configured via Kubernetes)
- ✅ Regular security updates via managed node groups

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review Terraform plan output
3. Consult AWS EKS documentation
4. Contact: careers@particle41.com

## License

MIT License

