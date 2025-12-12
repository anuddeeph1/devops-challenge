# Cost Optimization Guide

This guide explains the different cost configurations available for SimpleTimeService deployment.

## 📊 Configuration Comparison

| Configuration | Monthly Cost | Use Case | Trade-offs |
|---------------|--------------|----------|------------|
| **Default (terraform.tfvars)** | **~$164** | Demo/Testing | Single NAT, 1 replica |
| **Dev Optimized (terraform-dev.tfvars)** | **~$146** | Development | Spot instances, minimal setup |
| **Production** | **~$227** | Production | HA NAT, 2+ nodes, 3 replicas |

## 💰 Cost Breakdown by Configuration

### Current Default Configuration (`terraform.tfvars`)

**Monthly Cost: ~$164**

```hcl
single_nat_gateway = true      # Saves $33/month vs dual NAT
node_capacity_type = "ON_DEMAND"
node_desired_size = 1
app_replica_count = 1
```

| Resource | Cost/Month |
|----------|------------|
| EKS Control Plane | $73.00 |
| 1x t3a.medium (ON_DEMAND) | $30.37 |
| 1x NAT Gateway | $32.85 |
| NAT Data Processing | $2.25 |
| Application Load Balancer | $17.23 |
| EBS Storage (50 GB) | $4.00 |
| Data Transfer | $4.50 |
| **TOTAL** | **~$164/month** |

### Dev Optimized Configuration (`terraform-dev.tfvars`)

**Monthly Cost: ~$146**

```hcl
single_nat_gateway = true
node_capacity_type = "SPOT"        # Saves 60% on compute
node_desired_size = 1
app_replica_count = 1
enable_cluster_autoscaler = false
log_retention_days = 3
```

| Resource | Cost/Month |
|----------|------------|
| EKS Control Plane | $73.00 |
| 1x t3a.medium (SPOT) | $12.15 |
| 1x NAT Gateway | $32.85 |
| NAT Data Processing | $2.25 |
| Application Load Balancer | $17.23 |
| EBS Storage (50 GB) | $4.00 |
| Data Transfer | $4.50 |
| **TOTAL** | **~$146/month** |

**⚠️ SPOT Instance Considerations:**
- Can be interrupted by AWS with 2-minute notice
- Good for: Development, testing, non-critical workloads
- Not recommended for: Production, always-on services

### Production Configuration

**Monthly Cost: ~$227**

```hcl
single_nat_gateway = false         # Dual NAT for HA
node_capacity_type = "ON_DEMAND"
node_desired_size = 2
node_max_size = 4
app_replica_count = 3
enable_cluster_autoscaler = true
```

| Resource | Cost/Month |
|----------|------------|
| EKS Control Plane | $73.00 |
| 2x t3a.medium (ON_DEMAND) | $60.74 |
| 2x NAT Gateway | $65.70 |
| NAT Data Processing | $2.25 |
| Application Load Balancer | $17.23 |
| EBS Storage (100 GB) | $8.00 |
| Data Transfer | $4.50 |
| **TOTAL** | **~$231/month** |

## 🎯 How to Use Different Configurations

### Option 1: Use Default (Current - Balanced)

```bash
cd terraform
terraform init
terraform apply
```
**Cost: ~$164/month**

### Option 2: Use Dev Optimized (Maximum Savings)

```bash
cd terraform
terraform init
terraform apply -var-file=terraform-dev.tfvars
```
**Cost: ~$146/month**

### Option 3: Temporary Deployment (Demo Only)

```bash
cd terraform
terraform init
terraform apply -var-file=terraform-dev.tfvars

# Use for 2-3 hours, then destroy
terraform destroy

# Total cost: ~$1-2
```

## 💡 Cost Optimization Strategies

### 1. Single NAT Gateway
**Savings: $33/month**

```hcl
single_nat_gateway = true
```

✅ **Pros:**
- Significant cost savings
- Still provides private subnet internet access

❌ **Cons:**
- Single point of failure for outbound internet
- If NAT gateway fails, all private subnets lose internet

### 2. Spot Instances
**Savings: ~$18/month (60% off compute)**

```hcl
node_capacity_type = "SPOT"
```

✅ **Pros:**
- Major compute cost reduction
- Good for stateless workloads
- AWS gives 2-minute termination notice

❌ **Cons:**
- Can be terminated any time
- Not suitable for production
- May experience brief interruptions

### 3. Reduce Replicas
**Savings: Minimal (reduces pod resources only)**

```hcl
app_replica_count = 1
```

✅ **Pros:**
- Lower resource usage
- Simpler troubleshooting

❌ **Cons:**
- No high availability
- Zero downtime during updates not possible
- Single point of failure

### 4. Smaller Instance Type
**Savings: ~$15/month**

```hcl
node_instance_types = ["t3a.small"]  # 2 GB RAM vs 4 GB
```

✅ **Pros:**
- Lower compute costs
- Sufficient for small workloads

❌ **Cons:**
- Less memory and CPU
- May not handle high traffic
- Fewer pods per node

### 5. Reduce Log Retention
**Savings: ~$1-2/month**

```hcl
log_retention_days = 3  # vs 7 days
```

### 6. Disable Cluster Autoscaler
**Savings: ~$0.50/month**

```hcl
enable_cluster_autoscaler = false
```

## 🔄 Switching Between Configurations

### From Default to Dev Optimized

```bash
# Apply dev configuration
terraform apply -var-file=terraform-dev.tfvars

# Terraform will show changes:
# - Node capacity changes to SPOT
# - Cluster autoscaler disabled
# - Log retention reduced
```

### From Dev to Production

Create `terraform-prod.tfvars`:
```hcl
single_nat_gateway = false
node_capacity_type = "ON_DEMAND"
node_desired_size = 2
node_max_size = 4
app_replica_count = 3
enable_cluster_autoscaler = true
log_retention_days = 30
```

Apply:
```bash
terraform apply -var-file=terraform-prod.tfvars
```

## ⏱️ Hourly Cost (For Short-term Use)

| Configuration | Per Hour | 4 Hours | 8 Hours | 24 Hours |
|---------------|----------|---------|---------|----------|
| Default | $0.22 | $0.88 | $1.76 | $5.28 |
| Dev Optimized | $0.20 | $0.80 | $1.60 | $4.80 |
| Production | $0.31 | $1.24 | $2.48 | $7.44 |

## 🎓 Recommendations by Use Case

### Learning/Challenge Demo
**Use: Dev Optimized + Quick Destroy**
```bash
terraform apply -var-file=terraform-dev.tfvars
# Demo for 2-3 hours
terraform destroy
```
**Total Cost: $0.40-0.60**

### Development Environment
**Use: Default Configuration**
- Balance of cost and reliability
- Single NAT saves money
- ON_DEMAND for stability
**Monthly Cost: ~$164**

### Staging Environment
**Use: Default or slightly enhanced**
```hcl
single_nat_gateway = true  # Still cost-optimized
node_capacity_type = "ON_DEMAND"
node_desired_size = 2
app_replica_count = 2
```
**Monthly Cost: ~$194**

### Production Environment
**Use: Production Configuration**
- Dual NAT for high availability
- Multiple nodes with autoscaling
- ON_DEMAND instances only
**Monthly Cost: ~$227-280**

## 🛡️ Cost Monitoring

### Set Up AWS Budget Alerts

```bash
# Create a budget for $200/month
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json
```

### Monitor Costs Daily

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### Tag Resources for Cost Tracking

All resources are tagged with:
- `Project: simpletimeservice`
- `Environment: development/production`
- `ManagedBy: Terraform`
- `CostOptimized: true` (for dev configs)

## 🚨 Cost Alerts to Set

1. **Budget Alert**: $200/month threshold
2. **Anomaly Detection**: Unusual cost spikes
3. **Daily Digest**: Email with cost breakdown
4. **Forecast Alert**: Projected to exceed budget

## 📝 Cost Optimization Checklist

Before deploying:
- [ ] Choose appropriate configuration file
- [ ] Decide on NAT gateway strategy
- [ ] Select node capacity type (SPOT vs ON_DEMAND)
- [ ] Set appropriate replica count
- [ ] Configure log retention
- [ ] Set up AWS budget alerts
- [ ] Plan deployment duration
- [ ] Schedule destruction if temporary

After deploying:
- [ ] Monitor AWS Cost Explorer daily
- [ ] Check for unused resources
- [ ] Verify auto-scaling is working
- [ ] Review CloudWatch logs usage
- [ ] **DESTROY when not needed!**

## 🔥 Emergency Cost Reduction

If costs are too high:

```bash
# Option 1: Scale down immediately
terraform apply -var='node_desired_size=1' -var='app_replica_count=1'

# Option 2: Switch to Spot
terraform apply -var='node_capacity_type=SPOT'

# Option 3: Destroy everything
terraform destroy
```

## 📞 Support

Questions about costs?
- AWS Cost Explorer: https://console.aws.amazon.com/cost-management/
- AWS Pricing Calculator: https://calculator.aws/
- AWS Support: Create a billing inquiry

---

**Remember: The cheapest deployment is the one you destroy when not using it!** 🎯

