# GitHub Secrets Setup Guide

## 🔑 Required Secrets for CI/CD Pipeline

Your CI/CD pipeline needs these GitHub secrets to function properly.

---

## 📋 Quick Reference

### Minimum Required (1 secret):
```
DOCKERHUB_TOKEN - For pushing Docker images
```

### Full CI/CD (3 secrets):
```
DOCKERHUB_TOKEN         - Docker Hub access token
AWS_ACCESS_KEY_ID       - AWS access key
AWS_SECRET_ACCESS_KEY   - AWS secret key
```

---

## 🚀 Step-by-Step Setup

### 1. Go to Your GitHub Repository

```
https://github.com/anuddeeph1/devops-challenge
```

### 2. Navigate to Settings

```
Click: Settings → Secrets and variables → Actions
```

### 3. Add Repository Secrets

Click **"New repository secret"** and add each of the following:

---

## 🔐 Secret 1: DOCKERHUB_TOKEN (Required)

**Name**: `DOCKERHUB_TOKEN`

**Value**: Your Docker Hub Personal Access Token

**How to get it:**

1. Go to https://hub.docker.com/settings/security
2. Click **"New Access Token"**
3. Name: `GitHub Actions CI/CD`
4. Permissions: **Read, Write, Delete**
5. Click **Generate**
6. **Copy the token** (you won't see it again!)
7. Paste into GitHub secret

**Used for:**
- Pushing Docker images to Docker Hub
- Signing containers with Cosign
- Publishing multi-arch images

**Required in jobs:**
- `docker-build`
- `sign-container`

---

## 🔐 Secret 2: AWS_ACCESS_KEY_ID (Optional*)

**Name**: `AWS_ACCESS_KEY_ID`

**Value**: Your AWS access key ID

**How to get it:**

### Option A: Create New IAM User (Recommended)

1. Go to AWS Console → IAM → Users
2. Click **"Add user"**
3. Username: `github-actions-deploy`
4. Select: **Programmatic access**
5. Permissions: Attach policies
   - `AmazonEKSFullAccess`
   - `AmazonEC2FullAccess`  
   - `IAMFullAccess` (for IRSA)
6. Click through and **copy Access Key ID**

### Option B: Use Existing User

1. AWS Console → IAM → Users → Your user
2. Security credentials → **Create access key**
3. Use case: **Command Line Interface (CLI)**
4. **Copy Access Key ID**

**Used for:**
- Deploying to EKS cluster
- Updating kubeconfig
- Helm deployments

**Required in jobs:**
- `deploy-to-eks`

*Optional if you only want to build/test/scan without deploying

---

## 🔐 Secret 3: AWS_SECRET_ACCESS_KEY (Optional*)

**Name**: `AWS_SECRET_ACCESS_KEY`

**Value**: Your AWS secret access key

**How to get it:**

From the same access key creation above:
- **Copy Secret Access Key** (shown only once!)
- If you lose it, delete and create a new access key

**Used for:**
- Same as AWS_ACCESS_KEY_ID
- Authentication pair

**Required in jobs:**
- `deploy-to-eks`

*Optional if you only want to build/test/scan without deploying

---

## 🔐 Optional Secret: SLACK_WEBHOOK

**Name**: `SLACK_WEBHOOK`

**Value**: Your Slack webhook URL

**How to get it:**

1. Go to https://api.slack.com/apps
2. Create new app → From scratch
3. Add **Incoming Webhooks** feature
4. Activate and copy webhook URL

**Used for:**
- Sending deployment notifications to Slack
- Currently commented out in workflow

**To enable:**

Uncomment in `.github/workflows/ci-cd.yaml`:
```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## ✅ Verification Checklist

After adding secrets, verify:

- [ ] All 3 secrets added (or minimum 1)
- [ ] Secret names exactly match (case-sensitive)
- [ ] No extra spaces in values
- [ ] Docker Hub token has write permissions
- [ ] AWS credentials are for correct account
- [ ] Test a small push to trigger pipeline

---

## 🧪 Testing Your Secrets

### Test 1: Docker Hub Token

```bash
# Make a small change
echo "# Test" >> README.md
git add README.md
git commit -m "test: verify CI/CD pipeline"
git push origin main

# Check GitHub Actions tab
# - Build & Test should pass
# - Docker Build should push image
```

### Test 2: AWS Credentials

Push to main branch:
- Should deploy to EKS cluster
- Check EKS for updated pods
- Verify in GitHub Actions logs

---

## 🔍 Current Pipeline Configuration

Your pipeline is already configured with:

```yaml
env:
  APP_NAME: simpletimeservice
  AWS_REGION: us-west-1
  EKS_CLUSTER_NAME: test-cluster-cluster
  DOCKER_IMAGE: anuddeeph1/simpletimeservice
```

**These are hardcoded** - no secrets needed! ✅

---

## 📊 What Each Secret Enables

| Secret | Enables | Pipeline Jobs |
|--------|---------|---------------|
| `DOCKERHUB_TOKEN` | Docker push + signing | docker-build, sign-container |
| `AWS_ACCESS_KEY_ID` | EKS deployment | deploy-to-eks |
| `AWS_SECRET_ACCESS_KEY` | EKS deployment | deploy-to-eks |
| `SLACK_WEBHOOK` | Notifications | notify (if enabled) |

---

## ⚠️ Security Best Practices

### Do:
- ✅ Use tokens with minimal required permissions
- ✅ Rotate credentials regularly (every 90 days)
- ✅ Delete unused access keys
- ✅ Monitor usage in AWS CloudTrail
- ✅ Use different credentials for dev/prod

### Don't:
- ❌ Share secrets in chat/email
- ❌ Commit secrets to git
- ❌ Use admin credentials
- ❌ Reuse credentials across projects
- ❌ Leave old credentials active

---

## 🆘 Troubleshooting

### "Invalid Docker Hub credentials"

**Solution:**
1. Regenerate token at https://hub.docker.com/settings/security
2. Update `DOCKERHUB_TOKEN` in GitHub
3. Re-run workflow

### "AWS authorization failed"

**Solution:**
1. Verify IAM user has EKS permissions
2. Check access key is active
3. Update secrets in GitHub
4. Re-run workflow

### "Secret not found"

**Solution:**
1. Verify secret name exactly matches
2. Check you're in the correct repository
3. Verify secret is repository secret (not environment)

---

## 📱 Where to Find Secrets in GitHub

```
Repository → Settings → Secrets and variables → Actions → Repository secrets

You should see:
✅ DOCKERHUB_TOKEN
✅ AWS_ACCESS_KEY_ID  
✅ AWS_SECRET_ACCESS_KEY
```

---

## 🎯 Quick Setup Commands

### Check if secrets are set:

```bash
# In GitHub Actions log, you'll see:
# ***  (secrets are masked)
```

### Test pipeline:

```bash
# Trigger pipeline
git commit --allow-empty -m "test: trigger CI/CD"
git push origin main

# Watch at:
https://github.com/anuddeeph1/devops-challenge/actions
```

---

## 💡 Current Status

**Repository**: ✅ Pushed to GitHub  
**Secrets**: ⚠️ **Need to be added manually**  
**Pipeline**: ✅ Ready (will run after secrets added)  
**Application**: ✅ Live on AWS  

---

## 🏁 Next Steps

1. **Add GitHub secrets** (3 secrets above)
2. **Test pipeline** (make a small commit)
3. **Verify workflow** (check Actions tab)
4. **Submit to Particle41** (email with repo URL)

---

**Your pipeline will work automatically once secrets are added!** 🚀

---

## 📞 Support

If you need help:
- GitHub Secrets Docs: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- Docker Hub Tokens: https://docs.docker.com/docker-hub/access-tokens/
- AWS Access Keys: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html

