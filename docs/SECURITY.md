# Security Documentation

Comprehensive security implementation details for SimpleTimeService.

## Security Overview

SimpleTimeService implements multiple layers of security following industry best practices and compliance standards.

## Container Security

### Non-Root User

The application runs as a non-root user (UID 65532) to minimize attack surface.

**Dockerfile:**
```dockerfile
FROM gcr.io/distroless/static-debian12:nonroot
USER 65532:65532
```

**Kubernetes SecurityContext:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  fsGroup: 65532
```

### Distroless Base Image

Uses Google's distroless image which:
- Contains only the application and runtime dependencies
- No shell, package managers, or utilities
- Minimal attack surface (~15MB total size)
- Reduced vulnerability exposure

### Read-Only Root Filesystem

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

Prevents:
- Runtime file modifications
- Malware injection
- Unauthorized binary execution

### Dropped Capabilities

```yaml
securityContext:
  capabilities:
    drop:
    - ALL
```

Removes all Linux capabilities except those absolutely required.

### Security Scanning

Automated vulnerability scanning with:
- **Grype**: CVE detection
- **Syft**: SBOM generation
- **VEX**: Exploitability analysis
- **Cosign**: Image signing and attestation

## Network Security

### VPC Configuration

- **Private Subnets**: EKS nodes deployed in private subnets
- **Public Subnets**: Only ALB exposed publicly
- **NAT Gateways**: Nodes access internet via NAT
- **Security Groups**: Restrictive ingress/egress rules

### Security Groups

#### ALB Security Group
```hcl
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

#### EKS Node Security Group
```hcl
ingress {
  description              = "ALB to nodes"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}
```

### Load Balancer Security

- Health checks on `/health` endpoint
- Connection draining
- Deregistration delay
- SSL/TLS ready (HTTPS support)

## Kubernetes Security

### Pod Security Standards

Namespace enforces Pod Security Standards:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Baseline** enforcement prevents:
- Privileged containers
- Host namespace sharing
- Privilege escalation

**Restricted** audit/warn for:
- Running as root
- Writable root filesystem
- Unnecessary capabilities

### Service Account

Dedicated service account with IRSA (IAM Roles for Service Accounts):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: simpletimeservice
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::<ACCOUNT>:role/simpletimeservice-app"
```

Benefits:
- No AWS credentials in pods
- Fine-grained IAM permissions
- Automatic credential rotation
- CloudTrail audit logging

### Resource Limits

Prevents resource exhaustion attacks:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

### Health Probes

Multiple probe types ensure container health:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe:
  httpGet:
    path: /health
    port: http
  failureThreshold: 12
```

## IAM Security

### Least Privilege Principle

Application IAM role has minimal permissions:

```hcl
statement {
  actions = [
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "logs:DescribeLogStreams"
  ]
  resources = ["arn:aws:logs:*:*:*"]
}
```

### EKS Node IAM Role

Managed by Terraform with AWS managed policies:
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `AmazonSSMManagedInstanceCore` (optional)

## Data Security

### Encryption at Rest

- **EBS Volumes**: Encrypted by default
- **S3 State Bucket**: AES-256 encryption
- **DynamoDB Table**: Encrypted

### Encryption in Transit

- **ALB to Nodes**: HTTP (HTTPS ready)
- **Internal**: Kubernetes service mesh
- **AWS APIs**: TLS 1.2+

### Secrets Management

Kubernetes secrets for sensitive data:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  api-key: <base64-encoded>
```

Future: AWS Secrets Manager integration via External Secrets Operator.

## CI/CD Security

### GitHub Actions Security

- **Secrets**: Stored in GitHub encrypted secrets
- **OIDC**: Keyless signing with Cosign
- **Permissions**: Minimal required permissions per job
- **Artifact retention**: 90 days for compliance

### Container Signing

Images signed with Cosign using keyless signing:

```yaml
- name: Sign container image
  run: |
    cosign sign --yes ${{ secrets.DOCKERHUB_USERNAME }}/simpletimeservice:latest
```

Verification:

```bash
cosign verify \
  --certificate-identity-regexp=".*" \
  anuddeeph1/simpletimeservice:latest
```

### Vulnerability Scanning

Automated scanning in CI/CD:

1. **Build stage**: Scan during image build
2. **Push stage**: Scan before registry push
3. **Scheduled**: Daily scans of deployed images
4. **PR validation**: Scan on pull requests

### SBOM Generation

Software Bill of Materials for supply chain security:

- **CycloneDX JSON**: Industry standard format
- **SPDX JSON**: Alternative format
- **Stored with image**: Attached as artifact

## Compliance

### Standards

- **CIS Benchmarks**: EKS best practices
- **OWASP Top 10**: Application security
- **Pod Security Standards**: Kubernetes security
- **AWS Well-Architected**: Infrastructure best practices

### Audit Logging

- **CloudTrail**: AWS API calls
- **CloudWatch**: Application logs
- **EKS Control Plane**: Kubernetes audit logs
- **VPC Flow Logs**: Network traffic

## Security Monitoring

### CloudWatch Alarms

Set up alarms for:
- Unauthorized API calls
- Failed authentication attempts
- High error rates
- Resource exhaustion

### Security Hub

Enable AWS Security Hub for:
- Security findings aggregation
- Compliance checks
- Best practice recommendations

### GuardDuty

Enable for:
- Threat detection
- Malicious activity monitoring
- Unusual behavior alerts

## Incident Response

### Security Incident Procedure

1. **Detection**: CloudWatch/Security Hub alerts
2. **Containment**: Isolate affected resources
3. **Investigation**: Review logs and metrics
4. **Remediation**: Patch vulnerabilities
5. **Recovery**: Restore from clean state
6. **Post-mortem**: Document and improve

### Backup and Recovery

- Automated EKS backups (Velero recommended)
- S3 versioning for state files
- Database snapshots (if using RDS)
- DR plan with RTO/RPO targets

## Security Best Practices

### Development

- [ ] Never commit secrets to git
- [ ] Use .gitignore for sensitive files
- [ ] Run security scans locally
- [ ] Keep dependencies updated
- [ ] Use security linters

### Deployment

- [ ] Enable all security features
- [ ] Use private subnets for workloads
- [ ] Implement network policies
- [ ] Enable encryption everywhere
- [ ] Use managed services when possible

### Operations

- [ ] Regular security updates
- [ ] Monitor security alerts
- [ ] Review IAM permissions quarterly
- [ ] Rotate credentials regularly
- [ ] Conduct security audits

### Compliance

- [ ] Document security controls
- [ ] Maintain audit logs
- [ ] Perform regular assessments
- [ ] Track vulnerabilities
- [ ] Update security policies

## Security Tools

### Recommended Additional Tools

1. **Falco**: Runtime security monitoring
2. **OPA/Gatekeeper**: Policy enforcement
3. **Trivy**: Comprehensive security scanner
4. **Vault**: Secrets management
5. **Cert-Manager**: TLS certificate management

## Security Contacts

For security issues:
- Email: security@example.com
- Report vulnerabilities responsibly
- Include reproduction steps
- Provide POC if possible

## Regular Security Tasks

### Daily
- Monitor security alerts
- Review CloudWatch logs
- Check for failed deployments

### Weekly
- Review access logs
- Update security patches
- Scan for new vulnerabilities

### Monthly
- Review IAM permissions
- Audit user access
- Test backup restoration
- Security training

### Quarterly
- Conduct security assessment
- Update security documentation
- Review incident response plan
- Penetration testing

## References

- [EKS Security Best Practices](https://docs.aws.amazon.com/eks/latest/userguide/security.html)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
- [OWASP Container Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

