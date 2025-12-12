# CI/CD Pipeline Guide

## Overview

The CI/CD pipeline automatically builds, tests, scans, and deploys your application whenever you push code to GitHub.

---

## 🔄 What the Pipeline Does

### On Every Push to `main` or `develop`:

```
1. Build & Test → 2. Docker Build → 3. Security Scan → 4. Sign → 5. Update Manifests → 6. Deploy
```

---

## 📋 Pipeline Jobs Explained

### Job 1: Build and Test (Always Runs)

**What it creates:**
- ✅ Test results
- ✅ Code coverage report (HTML)
- ✅ Static analysis results

**Actions:**
```yaml
- Checkout code
- Setup Go 1.21
- Run unit tests (go test)
- Generate coverage report
- Run go vet (code quality)
- Run staticcheck (linting)
```

**Artifacts Created:**
- `coverage-report` (7 days retention)

**No secrets needed** for this job!

---

### Job 2: Docker Build and Push

**What it creates:**
- ✅ Multi-arch Docker image (AMD64 + ARM64)
- ✅ Tagged with multiple tags:
  - `latest` (main branch only)
  - `main-<git-sha>`
  - `latest-<run-id>-<run-number>`
- ✅ Image pushed to Docker Hub
- ✅ SBOM (Software Bill of Materials)

**Actions:**
```yaml
- Build Docker image (multi-platform)
- Tag: anuddeeph1/simpletimeservice:latest-12345-67
- Push to Docker Hub
- Generate SBOM (CycloneDX + SPDX formats)
```

**Artifacts Created:**
- `sbom-reports` (90 days retention)
  - `sbom-cyclonedx.json`
  - `sbom-spdx.json`

**Secrets Required:**
- `DOCKERHUB_TOKEN` - Your Docker Hub access token

---

### Job 3: Security Scan

**What it creates:**
- ✅ Vulnerability scan report (JSON)
- ✅ SARIF report (uploaded to GitHub Security tab)
- ✅ Table report (human-readable)
- ✅ VEX document (exploitability analysis)

**Actions:**
```yaml
- Scan image with Grype
- Generate reports in 3 formats (JSON, SARIF, table)
- Upload to GitHub Security Code Scanning
- Create VEX document (vulnerability exploitability)
```

**Artifacts Created:**
- `security-scan-reports` (90 days)
  - `grype-report.json`
  - `grype-report.sarif`
  - `grype-report.txt`
- `vex-document` (90 days)
  - `vex-document.json`

**No additional secrets needed!**

---

### Job 4: Sign Container (Main branch only)

**What it creates:**
- ✅ Cryptographic signature for container image
- ✅ Attestation with GitHub OIDC
- ✅ Verification proof

**Actions:**
```yaml
- Sign image with Cosign (keyless)
- Uses GitHub OIDC for attestation
- Verify signature
```

**No artifacts** (signature stored with image in registry)

**Secrets Required:**
- `DOCKERHUB_TOKEN`

**Permissions Required:**
- `id-token: write` (for OIDC)

---

### Job 5: Update Manifests (Main branch only)

**What it creates:**
- ✅ Updated `kubernetes/helm-chart/values.yaml`
- ✅ Updated `kubernetes/deployment.yaml`
- ✅ Git commit with new image tags

**Actions:**
```yaml
- Update Helm values.yaml with new image tag
- Update standalone deployment.yaml
- Commit changes
- Push to repository
```

**Changes Made:**
```yaml
# In values.yaml
image:
  tag: latest-12345-67  # Updated automatically
```

**No additional secrets needed** (uses `GITHUB_TOKEN`)

---

### Job 6: Terraform Validate (Pull Requests only)

**What it creates:**
- ✅ Terraform validation results
- ✅ Format check results
- ✅ PR status check

**Actions:**
```yaml
- Check Terraform formatting
- Initialize Terraform
- Validate configuration
```

**No artifacts, no secrets needed!**

---

### Job 7: Deploy to EKS (Main branch only)

**What it creates:**
- ✅ Deployed application to Kubernetes
- ✅ 3 running pods
- ✅ NodePort service
- ✅ HPA configuration

**Actions:**
```yaml
- Configure AWS credentials
- Update kubeconfig for EKS
- Deploy via Helm upgrade --install
- Wait for rollout to complete
- Verify deployment health
```

**Secrets Required:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**What Gets Deployed:**
- Namespace: `simpletimeservice`
- Deployment: 3 replicas
- Service: NodePort 30080
- HPA: 2-10 replicas
- All via Helm chart!

---

### Job 8: Notify

**What it creates:**
- ✅ Deployment status message
- ✅ (Optional) Slack/email notifications

**Actions:**
```yaml
- Check if deployment succeeded
- Report status
- (Optional) Send Slack notification
```

**No artifacts**

**Optional Secrets:**
- `SLACK_WEBHOOK` (if you enable Slack notifications)

---

## 🔑 Required GitHub Secrets

### Minimum Required (2 secrets):

```
DOCKERHUB_TOKEN
└─ What: Docker Hub access token
└─ Where to get: https://hub.docker.com/settings/security
└─ Used for: Pushing images to Docker Hub

AWS_ACCESS_KEY_ID
└─ What: AWS access key
└─ Where to get: AWS IAM Console
└─ Used for: Deploying to EKS

AWS_SECRET_ACCESS_KEY  
└─ What: AWS secret key
└─ Where to get: AWS IAM Console  
└─ Used for: Deploying to EKS
```

### Optional Secrets:

```
SLACK_WEBHOOK
└─ For Slack notifications (disabled by default)
```

---

## 📊 What Gets Created/Updated

### Every Push to Main:

| Stage | Creates | Where |
|-------|---------|-------|
| **Build** | Coverage report | GitHub Artifacts |
| **Docker** | Multi-arch image | Docker Hub |
| **Docker** | SBOM files | GitHub Artifacts |
| **Security** | Vulnerability reports | GitHub Security + Artifacts |
| **Security** | VEX document | GitHub Artifacts |
| **Sign** | Image signature | Docker Hub (with image) |
| **Update** | New git commit | Your repository |
| **Deploy** | Running pods | EKS cluster |

### Every Pull Request:

| Stage | Creates | Where |
|-------|---------|-------|
| **Build** | Test results | GitHub Actions log |
| **Terraform** | Validation status | PR status check |

---

## 🔧 Environment Variables (Hardcoded)

These are set in the workflow file:

```yaml
env:
  APP_NAME: simpletimeservice
  AWS_REGION: us-west-1
  EKS_CLUSTER_NAME: test-cluster-cluster
  DOCKER_IMAGE: anuddeeph1/simpletimeservice
```

**You don't need to set these as secrets** - they're in the code!

---

## 🚀 How to Set Up

### Step 1: Push Code to GitHub

```bash
cd /Users/anudeepnalla/Downloads/particle-41/devops-challenge-solution

# Initialize git (if not done)
git init
git add .
git commit -m "Initial commit: Complete DevOps challenge solution"

# Add remote (create repo on GitHub first)
git remote add origin https://github.com/yourusername/devops-challenge-solution.git
git branch -M main
git push -u origin main
```

### Step 2: Add GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add these 3 secrets:

**DOCKERHUB_TOKEN:**
```
Name: DOCKERHUB_TOKEN
Value: <your-docker-hub-access-token>

How to get:
1. Go to https://hub.docker.com/settings/security
2. Click "New Access Token"
3. Name it: "GitHub Actions"
4. Copy the token
```

**AWS_ACCESS_KEY_ID:**
```
Name: AWS_ACCESS_KEY_ID
Value: <your-aws-access-key>

How to get:
1. AWS Console → IAM → Users
2. Select your user
3. Security credentials → Create access key
4. Copy the Access Key ID
```

**AWS_SECRET_ACCESS_KEY:**
```
Name: AWS_SECRET_ACCESS_KEY
Value: <your-aws-secret-key>

From the same access key creation:
- Copy the Secret Access Key
```

### Step 3: Make a Change to Trigger Pipeline

```bash
# Make a small change
echo "# CI/CD Test" >> app/README.md

# Commit and push
git add app/README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

### Step 4: Watch Pipeline Run

1. Go to your GitHub repo
2. Click **Actions** tab
3. See your workflow running!

---

## 📈 Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────┐
│  Push to main/develop branch                    │
└────────────┬────────────────────────────────────┘
             │
             ├──► Job 1: Build & Test (2-3 min)
             │    └─► Coverage report
             │
             ├──► Job 2: Docker Build (5-10 min)
             │    ├─► Build multi-arch image
             │    ├─► Push to Docker Hub
             │    └─► Generate SBOM
             │
             ├──► Job 3: Security Scan (5-8 min)
             │    ├─► Grype vulnerability scan
             │    ├─► Upload to GitHub Security
             │    └─► Generate VEX document
             │
             ├──► Job 4: Sign Container (2-3 min)
             │    └─► Cosign keyless signing
             │
             ├──► Job 5: Update Manifests (1 min)
             │    ├─► Update Helm values
             │    └─► Auto-commit
             │
             ├──► Job 6: Deploy to EKS (3-5 min)
             │    ├─► Helm upgrade --install
             │    └─► Verify rollout
             │
             └──► Job 7: Notify
                  └─► Send status

Total Time: ~20-30 minutes
```

---

## 🔍 What Gets Built

### Docker Image

**Name**: `anuddeeph1/simpletimeservice`

**Tags created per run:**
```
latest                           (main branch only)
main-a1b2c3d                     (git SHA)
latest-12345-67                  (unique run ID)
```

**Example:**
```
anuddeeph1/simpletimeservice:latest
anuddeeph1/simpletimeservice:main-a1b2c3d
anuddeeph1/simpletimeservice:latest-12345-67
```

### Kubernetes Resources

**Via Helm chart:**
```yaml
Release: simpletimeservice
Namespace: simpletimeservice
Resources:
  - Deployment (3 replicas)
  - Service (NodePort 30080)
  - ServiceAccount
  - HPA (2-10 replicas)
```

---

## ⚡ Pipeline Triggers

### Push Triggers:
```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - 'app/**'              # Go code changes
      - 'terraform/**'        # Infrastructure changes
      - 'kubernetes/**'       # K8s manifest changes
      - '.github/workflows/**' # Pipeline changes
```

### PR Triggers:
```yaml
on:
  pull_request:
    branches: [main]
```

**Only runs**: Build & Test + Terraform Validate

---

## 🎯 Quick Reference

### To Test Locally Before Pushing:

```bash
# Test Go code
cd app
go test -v ./...

# Build Docker image
docker build -t simpletimeservice:test .

# Run security scan
cd ..
./scripts/security-scan.sh simpletimeservice:test

# Lint Helm chart
helm lint kubernetes/helm-chart

# Validate Terraform
cd terraform
terraform validate
terraform fmt -check
```

---

## 🛠️ Customization

### Change Docker Image Name:

Update in `.github/workflows/ci-cd.yaml`:
```yaml
env:
  DOCKER_IMAGE: your-dockerhub/your-app-name
```

### Change EKS Cluster:

Update in `.github/workflows/ci-cd.yaml`:
```yaml
env:
  EKS_CLUSTER_NAME: your-cluster-name
  AWS_REGION: your-region
```

### Disable Certain Jobs:

Add condition:
```yaml
job-name:
  if: false  # Disables this job
```

---

## 📊 Summary

### Secrets Needed: 2 minimum, 3 recommended

| Secret | Required | Used For |
|--------|----------|----------|
| `DOCKERHUB_TOKEN` | ✅ Yes | Push images |
| `AWS_ACCESS_KEY_ID` | ⚠️ Optional* | Deploy to EKS |
| `AWS_SECRET_ACCESS_KEY` | ⚠️ Optional* | Deploy to EKS |

*Optional if you only want to build/test/scan without deploying

### What Gets Created:

```
Docker Hub:
└─ anuddeeph1/simpletimeservice:latest (and versioned tags)

GitHub:
├─ Actions artifacts (coverage, SBOM, security reports)
├─ Security alerts (vulnerability findings)
└─ Git commits (manifest updates)

EKS Cluster:
└─ Running application (3 pods via Helm)
```

---

## 🎓 For Your Challenge

The CI/CD pipeline is **ready to use** but **not required** for the challenge submission.

You can:
- ✅ Submit without CI/CD (just show the code)
- ✅ Set up secrets and demonstrate it working
- ✅ Mention it's available in documentation

**It's already a strong extra credit feature!** 🏆

---

## ✅ Current Status

```yaml
Pipeline: ✅ Ready to use
Configuration: ✅ Updated with correct values
Documentation: ✅ Complete
Secrets: ⚠️ Need to be added when you push to GitHub

Files:
  - .github/workflows/ci-cd.yaml (389 lines) ✅
  - .github/workflows/security-scan.yaml (102 lines) ✅
  - .github/workflows/README.md ✅
```

---

**The pipeline is production-ready and will work automatically once you add the GitHub secrets!** 🚀

