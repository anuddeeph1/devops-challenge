# Deployment Guide

Complete step-by-step guide for deploying SimpleTimeService to AWS EKS.

## Prerequisites

### Required Tools

1. **Docker** 20.10+
   ```bash
   docker --version
   ```

2. **AWS CLI** 2.0+
   ```bash
   aws --version
   ```

3. **Terraform** 1.6.0+
   ```bash
   terraform --version
   ```

4. **kubectl** 1.28+
   ```bash
   kubectl version --client
   ```

5. **Go** 1.21+ (optional, for local development)
   ```bash
   go version
   ```

### AWS Account Setup

1. **Create AWS Account** or use existing
2. **Create IAM User** with appropriate permissions:
   - EC2 Full Access
   - EKS Full Access
   - VPC Full Access
   - ELB Full Access
   - IAM permissions for role creation
   - S3 and DynamoDB for Terraform backend

3. **Configure AWS CLI**:
   ```bash
   aws configure
   # AWS Access Key ID: <your-key>
   # AWS Secret Access Key: <your-secret>
   # Default region name: us-west-1
   # Default output format: json
   ```

4. **Verify credentials**:
   ```bash
   aws sts get-caller-identity
   ```

## Deployment Steps

### Step 1: Build and Test Application Locally

```bash
# Clone repository
git clone <your-repo-url>
cd devops-challenge-solution

# Build Docker image
cd app
docker build -t simpletimeservice:latest .

# Run container
docker run -d -p 8080:8080 --name simpletimeservice simpletimeservice:latest

# Test the application
curl http://localhost:8080/
curl http://localhost:8080/health

# Stop container
docker stop simpletimeservice
docker rm simpletimeservice
```

Expected response:
```json
{
  "timestamp": "2025-12-12T15:30:45.123456789Z",
  "ip": "172.17.0.1"
}
```

### Step 2: Push Image to Docker Hub

```bash
# Log in to Docker Hub
docker login
# Username: <your-dockerhub-username>
# Password: <your-dockerhub-token>

# Tag image
docker tag simpletimeservice:latest anuddeeph1/simpletimeservice:latest

# Push to registry
docker push anuddeeph1/simpletimeservice:latest

# Verify image is public
# Visit: https://hub.docker.com/r/anuddeeph1/simpletimeservice
```

### Step 3: Update Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
# Update with your Docker Hub username
app_image_repository = "anuddeeph1/simpletimeservice"

# Choose cost optimization settings
single_nat_gateway = true  # Use true for cost savings ($32/month)
node_desired_size = 2      # Minimum for HA

# Other variables as needed
```

### Step 4: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply

# Type 'yes' when prompted

# Wait 15-20 minutes for EKS cluster creation
```

**Important**: This will create resources in AWS and incur costs (~$150-230/month).

### Step 5: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name simpletimeservice-cluster \
  --region us-west-1

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 6: Deploy Application to Kubernetes

```bash
cd kubernetes

# Deploy all manifests
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app=simpletimeservice \
  -n simpletimeservice \
  --timeout=5m

# Check status
kubectl get pods -n simpletimeservice
kubectl get svc -n simpletimeservice
```

### Step 7: Get Application URL

```bash
# Get Load Balancer DNS name
cd ../terraform
ALB_DNS=$(terraform output -raw alb_dns_name)

echo "Application URL: http://${ALB_DNS}/"

# Test the application
curl http://${ALB_DNS}/
curl http://${ALB_DNS}/health
```

### Step 8: Enable Remote State Backend (Optional)

```bash
cd terraform

# Get backend configuration
terraform output backend_config

# Uncomment backend block in backend.tf
# Update with your AWS account ID

# Migrate state to S3
terraform init -migrate-state

# Type 'yes' to confirm migration
```

## Alternative: Automated Deployment

Use the provided deployment script:

```bash
# Deploy everything at once
./scripts/deploy.sh all

# Or deploy components separately
./scripts/deploy.sh terraform
./scripts/deploy.sh kubernetes
```

## Verification

### 1. Check Infrastructure

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=simpletimeservice-vpc" \
  --region us-west-1

# Check EKS cluster
aws eks describe-cluster \
  --name simpletimeservice-cluster \
  --region us-west-1

# Check Load Balancer
aws elbv2 describe-load-balancers \
  --names simpletimeservice-alb \
  --region us-west-1
```

### 2. Check Kubernetes Resources

```bash
# All pods running
kubectl get pods -n simpletimeservice

# Service created
kubectl get svc -n simpletimeservice

# HPA configured
kubectl get hpa -n simpletimeservice

# Check pod logs
kubectl logs -n simpletimeservice -l app=simpletimeservice --tail=50
```

### 3. Test Application

```bash
# Get endpoint
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)

# Test API
curl http://${ALB_DNS}/

# Test with custom header
curl -H "X-Forwarded-For: 203.0.113.42" http://${ALB_DNS}/

# Load test
ab -n 1000 -c 10 http://${ALB_DNS}/
```

## Troubleshooting

### Issue: Terraform Apply Fails

**Error**: Insufficient permissions

**Solution**:
```bash
# Check IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <your-username>

# Ensure you have required policies
```

### Issue: EKS Cluster Not Accessible

**Error**: `error: You must be logged in to the server (Unauthorized)`

**Solution**:
```bash
# Update kubeconfig again
aws eks update-kubeconfig \
  --name simpletimeservice-cluster \
  --region us-west-1

# Check AWS credentials
aws sts get-caller-identity
```

### Issue: Pods Not Starting

**Error**: `ImagePullBackOff`

**Solution**:
```bash
# Check if image exists in Docker Hub
docker pull anuddeeph1/simpletimeservice:latest

# Verify image name in deployment
kubectl describe pod <pod-name> -n simpletimeservice

# Update deployment if needed
kubectl set image deployment/simpletimeservice \
  simpletimeservice=anuddeeph1/simpletimeservice:latest \
  -n simpletimeservice
```

### Issue: Load Balancer Not Responding

**Error**: Connection timeout

**Solution**:
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id)

# Verify NodePort service
kubectl get svc simpletimeservice -n simpletimeservice
```

## Cleanup

To avoid ongoing AWS costs, destroy all resources:

```bash
# Using script
./scripts/cleanup.sh all

# Or manually
cd terraform
terraform destroy

# Type 'yes' when prompted
```

## Cost Optimization

### Development Environment

```hcl
# terraform/terraform.tfvars
single_nat_gateway = true       # Save $32/month
node_instance_types = ["t3.small"]  # Save $30/month
node_desired_size = 1           # Save $30/month
```

**Estimated monthly cost**: ~$100-120

### Production Environment

```hcl
# terraform/terraform.tfvars
single_nat_gateway = false      # High availability
node_instance_types = ["t3.medium"]
node_desired_size = 2           # Minimum for HA
node_max_size = 4               # Auto-scaling
```

**Estimated monthly cost**: ~$230

## Next Steps

1. **Set up CI/CD**: Configure GitHub Actions secrets
2. **Enable monitoring**: Deploy Prometheus + Grafana
3. **Configure DNS**: Add custom domain with Route53
4. **Enable HTTPS**: Configure SSL/TLS with ACM
5. **Add logging**: Deploy Fluent Bit for log aggregation
6. **Implement backup**: Configure automated backups
7. **Set up alerts**: Configure CloudWatch alarms

## Support

For issues:
1. Check CloudWatch logs
2. Review Terraform plan output
3. Consult AWS EKS documentation
4. Contact: careers@particle41.com

