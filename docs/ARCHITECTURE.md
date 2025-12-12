# Architecture Documentation

Detailed architecture and design decisions for SimpleTimeService.

## System Architecture

SimpleTimeService is deployed on AWS using a modern, cloud-native architecture with multiple layers of abstraction and security.

## Components

### 1. Application Layer

#### SimpleTimeService
- **Language**: Go 1.21
- **Framework**: Standard library (net/http)
- **Binary Size**: ~8MB (before Docker)
- **Image Size**: ~15MB (distroless)
- **Performance**: ~50,000 req/sec (single instance)

**Key Features**:
- Pure JSON responses
- X-Forwarded-For support
- Graceful shutdown
- Health check endpoint
- Structured logging

### 2. Container Layer

#### Docker Image
- **Base**: `gcr.io/distroless/static-debian12:nonroot`
- **Build**: Multi-stage Dockerfile
- **User**: nonroot (65532:65532)
- **Security**: Read-only filesystem, dropped capabilities

**Build Process**:
1. Build stage: Compile Go binary
2. Runtime stage: Copy binary to distroless
3. Security: Apply securityContext
4. Optimization: Static linking, stripped binary

### 3. Orchestration Layer

#### Kubernetes (EKS 1.28)
- **Deployment**: 3 replicas (default)
- **Service**: NodePort on 30080
- **HPA**: CPU-based auto-scaling (2-10 replicas)
- **Probes**: Liveness, readiness, startup

**Pod Anti-Affinity**:
```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - simpletimeservice
      topologyKey: kubernetes.io/hostname
```

Ensures pods are spread across different nodes for high availability.

### 4. Network Layer

#### AWS VPC
- **CIDR**: 10.0.0.0/16
- **Availability Zones**: 2 (us-west-1a, us-west-1b)
- **Public Subnets**: 2 (10.0.1.0/24, 10.0.2.0/24)
- **Private Subnets**: 2 (10.0.11.0/24, 10.0.12.0/24)
- **NAT Gateways**: 2 (high availability)

#### Application Load Balancer
- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Subnets**: Public subnets
- **Target**: NodePort service on EKS nodes
- **Health Check**: HTTP GET /health every 30s

### 5. Compute Layer

#### EKS Worker Nodes
- **Instance Type**: t3.medium (default)
- **Min**: 2 nodes
- **Max**: 4 nodes
- **Desired**: 2 nodes
- **Subnets**: Private subnets only
- **AMI**: EKS-optimized Amazon Linux 2

**Node Specifications**:
- vCPU: 2
- Memory: 4 GiB
- Network: Up to 5 Gigabit
- Storage: 50 GB EBS (gp3)

### 6. Security Layer

#### IAM Roles
1. **EKS Cluster Role**: Manage cluster
2. **Node Group Role**: Node permissions
3. **App Service Account Role**: IRSA for application

#### Security Groups
1. **ALB Security Group**: Allow 80/443 from internet
2. **Node Security Group**: Allow traffic from ALB, cluster API
3. **Cluster Security Group**: Cluster internal communication

### 7. State Management

#### Terraform Backend
- **Storage**: S3 bucket with versioning
- **Locking**: DynamoDB table
- **Encryption**: AES-256
- **Retention**: 90 days for old versions

## Data Flow

### Request Flow

```
Internet → ALB → NodePort → Pod → Container → Application
```

1. **Client Request**: HTTP request to ALB DNS
2. **ALB**: Routes to healthy target (EKS node)
3. **NodePort**: Forwards to pod on port 8080
4. **Pod**: Container receives request
5. **Application**: Processes and returns JSON
6. **Response**: Same path in reverse

### IP Detection Flow

```
Client → ALB (adds X-Forwarded-For) → Application (reads header)
```

Application priority:
1. X-Forwarded-For (first IP)
2. X-Real-IP
3. RemoteAddr

## Scaling Architecture

### Horizontal Pod Autoscaler (HPA)

**Metrics**:
- CPU: Target 70%
- Memory: Target 80%

**Behavior**:
- Scale up: Add up to 4 pods every 15s
- Scale down: Remove up to 50% every 5min

**Algorithm**:
```
desiredReplicas = ceil[currentReplicas * (currentMetricValue / targetMetricValue)]
```

### Cluster Autoscaler

Automatically adds/removes nodes based on:
- Pending pods (scale up)
- Underutilized nodes (scale down)

**Configuration**:
- Scale up: When pods can't be scheduled
- Scale down: After 10 minutes of low utilization
- Min nodes: 2
- Max nodes: 4

## High Availability

### Application Level
- Multiple replicas (3)
- Pod anti-affinity
- Rolling updates
- Health probes

### Infrastructure Level
- Multi-AZ deployment
- Dual NAT gateways
- ALB health checks
- Auto-scaling groups

### Failure Scenarios

| Scenario | Impact | Recovery |
|----------|--------|----------|
| Pod crash | 2/3 available | Immediate restart |
| Node failure | 1 AZ down | Pods rescheduled |
| AZ failure | 50% capacity | Failover to other AZ |
| Region failure | Full outage | DR in another region |

## Performance Architecture

### Resource Allocation

Per pod:
- CPU request: 100m (0.1 cores)
- CPU limit: 500m (0.5 cores)
- Memory request: 64Mi
- Memory limit: 256Mi

### Capacity Planning

**Single pod**:
- Throughput: ~10,000 req/sec
- Latency: <1ms (p50), <5ms (p99)
- Memory: ~10MB resident

**3 replicas**:
- Throughput: ~30,000 req/sec
- Concurrent connections: ~3,000

**10 replicas (max HPA)**:
- Throughput: ~100,000 req/sec
- Concurrent connections: ~10,000

### Load Balancer

- Connection idle timeout: 60s
- Request timeout: 60s
- Deregistration delay: 30s
- Health check: 30s interval

## Monitoring Architecture

### Metrics Collection

```
Application → Kubernetes Metrics Server → HPA
EKS Nodes → CloudWatch Agent → CloudWatch
ALB → CloudWatch Metrics → Alarms
```

### Key Metrics

**Application**:
- Request rate (req/sec)
- Response time (ms)
- Error rate (%)
- Active connections

**Infrastructure**:
- CPU utilization (%)
- Memory utilization (%)
- Network I/O (bytes/sec)
- Disk I/O (IOPS)

**Business**:
- Availability (%)
- SLA compliance
- Cost per request
- User sessions

## Deployment Architecture

### GitOps Flow

```
Git Push → GitHub Actions → Build → Scan → Push → Deploy
```

1. **Trigger**: Push to main branch
2. **Build**: Compile Go + Docker build
3. **Scan**: Grype + Syft + VEX
4. **Sign**: Cosign attestation
5. **Push**: Upload to Docker Hub
6. **Update**: Modify Kubernetes manifests
7. **Deploy**: kubectl apply to EKS

### CI/CD Pipeline

**Stages**:
1. Build & Test (3-5 min)
2. Security Scan (5-8 min)
3. Docker Build (5-10 min)
4. Sign & Attest (2-3 min)
5. Deploy to EKS (3-5 min)

**Total**: 18-31 minutes

## Cost Architecture

### Monthly Costs (us-west-1)

| Component | Cost |
|-----------|------|
| EKS Control Plane | $73 |
| EC2 Nodes (2x t3.medium) | $60 |
| NAT Gateway (2x) | $65 |
| Application Load Balancer | $23 |
| EBS Volumes (100 GB) | $8 |
| Data Transfer (50 GB) | $5 |
| **Total** | **~$234/month** |

### Cost Optimization

**Development** (~$100/month):
- Single NAT gateway
- t3.small instances
- Single node
- Spot instances

**Production** (~$230/month):
- Dual NAT gateways
- t3.medium instances
- 2-4 nodes
- On-demand instances

## Security Architecture

### Defense in Depth

**Layer 1**: Network (VPC, Security Groups)
**Layer 2**: Infrastructure (IAM, KMS)
**Layer 3**: Platform (EKS, Pod Security)
**Layer 4**: Container (Distroless, non-root)
**Layer 5**: Application (Input validation)

### Zero Trust

- All traffic authenticated
- Least privilege access
- Encrypt everything
- Audit all actions
- Verify don't trust

## Disaster Recovery

### Backup Strategy

**Application**: Stateless, no backup needed
**Infrastructure**: Terraform state in S3
**Configuration**: Git repository

### Recovery Objectives

- **RTO** (Recovery Time Objective): 30 minutes
- **RPO** (Recovery Point Objective): 0 (stateless)

### DR Procedures

1. **Regional Failure**:
   - Deploy to new region
   - Update DNS (Route53)
   - Verify functionality

2. **Data Loss**:
   - Restore Terraform state from S3
   - Redeploy infrastructure
   - Verify configuration

## Future Enhancements

### Short Term
- [ ] Add HTTPS support with ACM
- [ ] Implement custom domain with Route53
- [ ] Add Prometheus monitoring
- [ ] Deploy Grafana dashboards
- [ ] Implement distributed tracing

### Medium Term
- [ ] Multi-region deployment
- [ ] Service mesh (Istio/Linkerd)
- [ ] Advanced observability
- [ ] Chaos engineering
- [ ] Performance tuning

### Long Term
- [ ] Global load balancing
- [ ] Multi-cloud support
- [ ] Edge computing
- [ ] Serverless migration
- [ ] AI/ML integration

## References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Architecture](https://kubernetes.io/docs/concepts/architecture/)
- [12-Factor App](https://12factor.net/)
- [Cloud Native Patterns](https://www.cnpatterns.org/)
- [Site Reliability Engineering](https://sre.google/books/)

