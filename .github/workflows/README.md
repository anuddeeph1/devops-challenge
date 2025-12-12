# GitHub Actions CI/CD Pipelines

This directory contains automated CI/CD workflows for SimpleTimeService.

## Workflows

### 1. `ci-cd.yaml` - Main CI/CD Pipeline

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`

**Jobs:**

#### Build and Test (Always runs)
- Checkout code
- Setup Go 1.21
- Run unit tests
- Generate coverage report
- Run static analysis

#### Docker Build and Push (Push only)
- Multi-arch build (amd64, arm64)
- Tag with git SHA and run ID
- Push to Docker Hub: `anuddeeph1/simpletimeservice`
- Generate SBOM (CycloneDX format)

#### Security Scan (Push only)
- Grype vulnerability scanning
- SBOM generation (CycloneDX + SPDX)
- VEX document creation
- Upload to GitHub Security

#### Sign Container (Main branch only)
- Cosign keyless signing
- GitHub OIDC attestation
- Verification

#### Update Manifests (Main branch only)
- Update Helm chart values
- Update Kubernetes deployment
- Auto-commit changes

#### Deploy to EKS (Main branch only)
- Configure AWS credentials
- Update kubeconfig
- Deploy via Helm
- Verify rollout

### 2. `security-scan.yaml` - Scheduled Security Scans

**Triggers:**
- Daily at 2 AM UTC
- Manual trigger (workflow_dispatch)

**Jobs:**

#### Scan Latest Image
- Pull latest image from Docker Hub
- Run Grype scan
- Generate reports (JSON, SARIF, table)
- Upload to GitHub Security

#### Scan Dependencies
- Run govulncheck on Go code
- Run nancy (Sonatype OSS Index)
- Check for vulnerable dependencies

---

## Required GitHub Secrets

### Docker Hub
```
DOCKERHUB_USERNAME - Not needed (hardcoded as anuddeeph1)
DOCKERHUB_TOKEN    - Docker Hub access token
```

### AWS (for EKS deployment)
```
AWS_ACCESS_KEY_ID     - AWS access key
AWS_SECRET_ACCESS_KEY - AWS secret key
```

**Note**: `DOCKERHUB_USERNAME` is not required since we're using `anuddeeph1` directly in the code.

---

## Setting Up Secrets

### In GitHub Repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**

2. Click **New repository secret**

3. Add these secrets:

   **DOCKERHUB_TOKEN**
   ```
   Value: Your Docker Hub access token
   How to get: https://hub.docker.com/settings/security
   ```

   **AWS_ACCESS_KEY_ID**
   ```
   Value: Your AWS access key
   ```

   **AWS_SECRET_ACCESS_KEY**
   ```
   Value: Your AWS secret key
   ```

---

## Pipeline Features

### ✅ Automated
- Build on every push
- Test on every PR
- Deploy on main branch
- Security scan daily

### ✅ Security
- Vulnerability scanning
- SBOM generation
- Container signing
- GitHub Security integration

### ✅ Quality
- Unit tests
- Code coverage
- Static analysis
- Linting

### ✅ Deployment
- Helm-based deployment
- Rolling updates
- Health check verification
- Auto-rollback on failure

---

## Workflow Customization

### Change Deployment Target

Update cluster name in `ci-cd.yaml`:
```yaml
env:
  EKS_CLUSTER_NAME: test-cluster-cluster  # Change this
```

### Change Image Repository

Update in `ci-cd.yaml`:
```yaml
env:
  DOCKER_IMAGE: anuddeeph1/simpletimeservice  # Change this
```

### Disable Certain Jobs

Add conditions to jobs:
```yaml
job-name:
  if: false  # Disable this job
```

### Change Branch Strategy

Update triggers:
```yaml
on:
  push:
    branches: [main, develop, feature/*]  # Add more branches
```

---

## Testing Pipeline Locally

### Test Docker Build
```bash
cd app
docker build -t simpletimeservice:test .
```

### Test Security Scan
```bash
./scripts/security-scan.sh simpletimeservice:test
```

### Test Helm Deployment
```bash
helm lint kubernetes/helm-chart
helm template test kubernetes/helm-chart
```

---

## Troubleshooting

### Pipeline Fails on Docker Push

**Issue**: Permission denied  
**Solution**: Check DOCKERHUB_TOKEN secret is valid

### Pipeline Fails on EKS Deploy

**Issue**: kubectl unauthorized  
**Solution**: Check AWS credentials have EKS permissions

### Security Scan Times Out

**Issue**: Image too large  
**Solution**: Increase timeout in workflow

---

## Monitoring

### View Workflow Runs
- Go to **Actions** tab in GitHub
- Click on workflow name
- View run details

### View Security Alerts
- Go to **Security** tab
- Click **Code scanning alerts**
- Review Grype findings

---

## Best Practices

- ✅ Run on feature branches
- ✅ Require PR approvals
- ✅ Block merge on failed checks
- ✅ Review security findings
- ✅ Keep secrets secure
- ✅ Rotate credentials regularly

---

## Next Steps

1. **Push to GitHub** - Workflows will run automatically
2. **Add secrets** - Configure GitHub repository secrets
3. **Test PR** - Create a PR to test validation
4. **Monitor** - Watch Actions tab for results

---

**Your CI/CD pipeline is production-ready!** 🚀

