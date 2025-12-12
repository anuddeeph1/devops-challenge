# Troubleshooting Guide

Common issues and solutions for SimpleTimeService deployment.

## Table of Contents

- [Docker Issues](#docker-issues)
- [AWS/Terraform Issues](#awsterraform-issues)
- [Kubernetes Issues](#kubernetes-issues)
- [Application Issues](#application-issues)
- [Network Issues](#network-issues)
- [Performance Issues](#performance-issues)

## Docker Issues

### Container Won't Start

**Symptom**: Container exits immediately after start

**Diagnosis**:
```bash
docker logs <container-id>
docker inspect <container-id>
```

**Common Causes**:

1. **Port already in use**
   ```bash
   # Find process using port 8080
   lsof -i :8080
   # Kill the process
   kill -9 <PID>
   # Or use different port
   docker run -p 9000:8080 simpletimeservice:latest
   ```

2. **Missing environment variables**
   ```bash
   docker run -e PORT=8080 simpletimeservice:latest
   ```

3. **Binary permissions**
   ```bash
   # Rebuild with correct permissions
   cd app
   docker build --no-cache -t simpletimeservice:latest .
   ```

### Image Build Fails

**Symptom**: `docker build` command fails

**Diagnosis**:
```bash
docker build --progress=plain --no-cache -t simpletimeservice:latest .
```

**Solutions**:

1. **Go build fails**
   ```bash
   cd app
   go mod tidy
   go build -o simpletimeservice main.go
   ```

2. **Network issues**
   ```bash
   # Check Docker proxy settings
   docker info | grep Proxy
   ```

3. **Disk space**
   ```bash
   # Clean up Docker
   docker system prune -a
   ```

### Cannot Push to Docker Hub

**Symptom**: `denied: requested access to the resource is denied`

**Solution**:
```bash
# Login again
docker login

# Verify correct tag
docker tag simpletimeservice:latest anuddeeph1/simpletimeservice:latest

# Push with correct name
docker push anuddeeph1/simpletimeservice:latest
```

## AWS/Terraform Issues

### Terraform Init Fails

**Symptom**: `Error: Failed to install provider`

**Solutions**:

1. **Network/proxy issues**
   ```bash
   export HTTPS_PROXY=http://proxy:port
   terraform init
   ```

2. **Lock file conflict**
   ```bash
   rm .terraform.lock.hcl
   terraform init
   ```

3. **Corrupted cache**
   ```bash
   rm -rf .terraform
   terraform init
   ```

### Terraform Apply Fails

**Symptom**: Various errors during `terraform apply`

**Common Issues**:

1. **Insufficient IAM permissions**
   ```bash
   # Check current user
   aws sts get-caller-identity
   
   # Required permissions:
   # - EC2 Full Access
   # - EKS Full Access
   # - IAM (create roles)
   # - VPC Full Access
   # - ELB Full Access
   ```

2. **Resource quota exceeded**
   ```bash
   # Check service quotas
   aws service-quotas list-service-quotas \
     --service-code ec2 \
     --region us-west-1
   
   # Request quota increase if needed
   ```

3. **Resource name conflict**
   ```bash
   # Change project name in terraform.tfvars
   project_name = "simpletimeservice-v2"
   ```

4. **State lock**
   ```bash
   # Force unlock (use with caution)
   terraform force-unlock <lock-id>
   ```

### EKS Cluster Creation Stuck

**Symptom**: Cluster stays in "CREATING" status for >30 minutes

**Diagnosis**:
```bash
aws eks describe-cluster --name simpletimeservice-cluster --region us-west-1

# Check CloudWatch logs
aws logs tail /aws/eks/simpletimeservice-cluster/cluster --follow
```

**Solutions**:

1. **VPC/Subnet issues**
   - Ensure subnets have proper tags
   - Check route tables
   - Verify NAT gateway configuration

2. **IAM role issues**
   ```bash
   # Verify cluster role
   aws iam get-role --role-name <cluster-role-name>
   ```

3. **Timeout (destroy and retry)**
   ```bash
   terraform destroy -target=module.eks
   terraform apply
   ```

### Cannot Connect to EKS Cluster

**Symptom**: `error: You must be logged in to the server (Unauthorized)`

**Solutions**:

1. **Update kubeconfig**
   ```bash
   aws eks update-kubeconfig \
     --name simpletimeservice-cluster \
     --region us-west-1
   ```

2. **Check AWS credentials**
   ```bash
   aws sts get-caller-identity
   ```

3. **Verify cluster endpoint**
   ```bash
   aws eks describe-cluster \
     --name simpletimeservice-cluster \
     --region us-west-1 \
     --query 'cluster.endpoint'
   ```

4. **IAM authentication**
   ```bash
   # Install aws-iam-authenticator if needed
   brew install aws-iam-authenticator
   
   # Or use AWS CLI
   aws eks get-token --cluster-name simpletimeservice-cluster
   ```

## Kubernetes Issues

### Pods Not Starting

**Symptom**: Pods stuck in `Pending`, `ImagePullBackOff`, or `CrashLoopBackOff`

**Diagnosis**:
```bash
kubectl get pods -n simpletimeservice
kubectl describe pod <pod-name> -n simpletimeservice
kubectl logs <pod-name> -n simpletimeservice
```

**Solutions by Status**:

1. **Pending**
   ```bash
   # Check node resources
   kubectl describe nodes
   
   # Check events
   kubectl get events -n simpletimeservice --sort-by='.lastTimestamp'
   
   # Possible causes:
   # - Insufficient node resources
   # - Node selector mismatch
   # - Taints/tolerations
   ```

2. **ImagePullBackOff**
   ```bash
   # Verify image exists
   docker pull anuddeeph1/simpletimeservice:latest
   
   # Check image name in deployment
   kubectl get deployment simpletimeservice -n simpletimeservice -o yaml | grep image:
   
   # Update if needed
   kubectl set image deployment/simpletimeservice \
     simpletimeservice=anuddeeph1/simpletimeservice:latest \
     -n simpletimeservice
   ```

3. **CrashLoopBackOff**
   ```bash
   # Check logs
   kubectl logs <pod-name> -n simpletimeservice --previous
   
   # Common causes:
   # - Application error
   # - Port conflict
   # - Liveness probe failing
   ```

### Service Not Accessible

**Symptom**: Cannot access application via service

**Diagnosis**:
```bash
kubectl get svc -n simpletimeservice
kubectl describe svc simpletimeservice -n simpletimeservice
kubectl get endpoints -n simpletimeservice
```

**Solutions**:

1. **No endpoints**
   ```bash
   # Check if pods are ready
   kubectl get pods -n simpletimeservice
   
   # Check selector matches
   kubectl get deployment simpletimeservice -n simpletimeservice -o yaml | grep -A3 selector:
   kubectl get svc simpletimeservice -n simpletimeservice -o yaml | grep -A3 selector:
   ```

2. **NodePort not working**
   ```bash
   # Check security groups allow NodePort range (30000-32767)
   aws ec2 describe-security-groups \
     --group-ids <node-security-group-id>
   
   # Test directly to node
   kubectl get nodes -o wide
   curl http://<node-ip>:30080/health
   ```

### HPA Not Scaling

**Symptom**: HPA not scaling pods based on load

**Diagnosis**:
```bash
kubectl get hpa -n simpletimeservice
kubectl describe hpa simpletimeservice-hpa -n simpletimeservice
kubectl top pods -n simpletimeservice
kubectl top nodes
```

**Solutions**:

1. **Metrics server not installed**
   ```bash
   # Check if metrics-server is running
   kubectl get deployment metrics-server -n kube-system
   
   # Install if needed
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

2. **No resource requests set**
   ```bash
   # HPA requires resource requests
   kubectl get deployment simpletimeservice -n simpletimeservice -o yaml | grep -A5 resources:
   ```

3. **Not enough load**
   ```bash
   # Generate load
   kubectl run -it --rm load-generator --image=busybox /bin/sh
   while true; do wget -q -O- http://simpletimeservice.simpletimeservice.svc.cluster.local:8080; done
   ```

## Application Issues

### Application Returns Wrong IP

**Symptom**: `/` endpoint returns internal IP instead of client IP

**Diagnosis**:
```bash
# Test with header
curl -H "X-Forwarded-For: 203.0.113.42" http://<alb-dns>/
```

**Solution**:

Verify ALB is configured to add X-Forwarded-For header:
```bash
aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn <alb-arn> \
  --query 'Attributes[?Key==`routing.http.xff_client_port.enabled`]'
```

### Health Check Failing

**Symptom**: ALB marks targets as unhealthy

**Diagnosis**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Check from inside cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://simpletimeservice.simpletimeservice.svc.cluster.local:8080/health
```

**Solutions**:

1. **Wrong health check path**
   - Verify path is `/health`
   - Check port is 30080 (NodePort)

2. **Firewall blocking**
   - Check security groups
   - Verify network policies

3. **Application not responding**
   ```bash
   kubectl logs -n simpletimeservice -l app=simpletimeservice --tail=50
   ```

## Network Issues

### Cannot Access ALB

**Symptom**: ALB DNS name not resolving or connection timeout

**Diagnosis**:
```bash
# Check ALB status
aws elbv2 describe-load-balancers \
  --names simpletimeservice-alb \
  --region us-west-1

# Check DNS resolution
nslookup <alb-dns-name>

# Check connectivity
curl -v http://<alb-dns-name>/health
```

**Solutions**:

1. **ALB not provisioned**
   ```bash
   # Check Terraform output
   cd terraform
   terraform output alb_dns_name
   
   # Wait for provisioning (can take 5-10 minutes)
   ```

2. **Security group blocking**
   ```bash
   # Verify ALB security group allows port 80
   aws ec2 describe-security-groups \
     --group-ids <alb-security-group-id> \
     --query 'SecurityGroups[0].IpPermissions'
   ```

3. **Target group unhealthy**
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <target-group-arn>
   ```

### Nodes Cannot Access Internet

**Symptom**: Pods cannot pull images or access external services

**Diagnosis**:
```bash
# Test from pod
kubectl run -it --rm test --image=busybox --restart=Never -- \
  wget -O- https://www.google.com

# Check NAT gateway
aws ec2 describe-nat-gateways --region us-west-1
```

**Solutions**:

1. **NAT gateway issues**
   ```bash
   # Verify NAT gateway state
   aws ec2 describe-nat-gateways \
     --filter "Name=state,Values=available" \
     --region us-west-1
   ```

2. **Route table misconfigured**
   ```bash
   # Check private subnet route tables
   aws ec2 describe-route-tables \
     --filters "Name=tag:Name,Values=*private*" \
     --region us-west-1
   
   # Should have route to NAT gateway for 0.0.0.0/0
   ```

## Performance Issues

### High Latency

**Symptom**: Slow response times

**Diagnosis**:
```bash
# Test latency
time curl http://<alb-dns>/

# Check pod resources
kubectl top pods -n simpletimeservice

# Check node resources
kubectl top nodes
```

**Solutions**:

1. **CPU throttling**
   ```bash
   # Increase CPU limits
   kubectl set resources deployment simpletimeservice \
     --limits=cpu=1000m \
     -n simpletimeservice
   ```

2. **Too few replicas**
   ```bash
   # Scale up
   kubectl scale deployment simpletimeservice --replicas=5 -n simpletimeservice
   ```

3. **Network latency**
   ```bash
   # Check if ALB and nodes are in different AZs
   # Prefer same-AZ routing
   ```

### High Error Rate

**Symptom**: 5xx errors from application

**Diagnosis**:
```bash
# Check application logs
kubectl logs -n simpletimeservice -l app=simpletimeservice --tail=100

# Check ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<alb-name> \
  --start-time 2025-12-12T00:00:00Z \
  --end-time 2025-12-12T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

**Solutions**:

1. **Application crashes**
   ```bash
   # Check restart count
   kubectl get pods -n simpletimeservice
   
   # View crash logs
   kubectl logs <pod-name> -n simpletimeservice --previous
   ```

2. **Resource exhaustion**
   ```bash
   # Check OOMKilled
   kubectl describe pod <pod-name> -n simpletimeservice | grep -i oom
   
   # Increase memory limit
   kubectl set resources deployment simpletimeservice \
     --limits=memory=512Mi \
     -n simpletimeservice
   ```

## Getting Help

If you've tried these solutions and still have issues:

1. **Collect diagnostics**:
   ```bash
   # Save all resources
   kubectl get all -n simpletimeservice -o yaml > diagnostics.yaml
   
   # Save events
   kubectl get events -n simpletimeservice > events.log
   
   # Save pod logs
   kubectl logs -n simpletimeservice -l app=simpletimeservice > app.log
   ```

2. **Check CloudWatch logs**:
   ```bash
   aws logs tail /aws/eks/simpletimeservice-cluster/cluster --follow
   ```

3. **Review Terraform state**:
   ```bash
   cd terraform
   terraform show
   ```

4. **Contact support**:
   - Email: careers@particle41.com
   - Include diagnostics files
   - Describe steps to reproduce
   - Share error messages

## Prevention

### Pre-flight Checks

Before deploying:
- [ ] AWS credentials configured
- [ ] Sufficient IAM permissions
- [ ] Region quotas checked
- [ ] Docker image built and tested
- [ ] Terraform validated
- [ ] Cost estimated

### Monitoring

Set up monitoring to catch issues early:
- [ ] CloudWatch alarms
- [ ] Application metrics
- [ ] Resource utilization
- [ ] Error rates
- [ ] Health checks

### Regular Maintenance

- [ ] Update dependencies weekly
- [ ] Review logs daily
- [ ] Check security scans
- [ ] Test backups monthly
- [ ] Update documentation

