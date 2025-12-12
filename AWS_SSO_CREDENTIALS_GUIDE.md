# AWS SSO Credentials for GitHub Actions

## 🔐 Using Temporary SSO Credentials

Since you're using AWS SSO, you'll use **temporary session credentials** that expire.

---

## 📋 Required GitHub Secrets (4 total)

### Repository Secrets to Add:

```
1. DOCKERHUB_TOKEN
2. AWS_ACCESS_KEY_ID
3. AWS_SECRET_ACCESS_KEY  
4. AWS_SESSION_TOKEN (NEW!)
```

---

## 🔧 How to Get Your SSO Session Credentials

### Step 1: Login via SSO

```bash
export AWS_PROFILE=devtest
aws sso login --profile devtest
```

### Step 2: Get Session Credentials

```bash
# Get the temporary credentials
aws configure export-credentials --profile devtest --format env

# Or manually:
cat ~/.aws/cli/cache/*.json | jq -r '.Credentials | "AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nAWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nAWS_SESSION_TOKEN=\(.SessionToken)"'
```

### Step 3: Copy Each Value

You'll see output like:
```bash
AWS_ACCESS_KEY_ID=ASIA...
AWS_SECRET_ACCESS_KEY=abc123...
AWS_SESSION_TOKEN=IQoJb3JpZ2luX2VjEH...  # ← This is very long!
```

---

## 🎯 Add to GitHub Secrets

### 1. DOCKERHUB_TOKEN

```
Name: DOCKERHUB_TOKEN
Value: <your-docker-hub-token>
```

### 2. AWS_ACCESS_KEY_ID  

```
Name: AWS_ACCESS_KEY_ID
Value: ASIA...  (from SSO credentials above)
```

### 3. AWS_SECRET_ACCESS_KEY

```
Name: AWS_SECRET_ACCESS_KEY
Value: abc123...  (from SSO credentials above)
```

### 4. AWS_SESSION_TOKEN (NEW!)

```
Name: AWS_SESSION_TOKEN
Value: IQoJb3JpZ2luX2VjEH...  (from SSO credentials - very long!)
```

---

## ⏰ **Important: Credentials Expire!**

**SSO credentials expire in 1-12 hours** (usually 1-4 hours)

### When They Expire:

❌ GitHub Actions will fail with: "ExpiredToken"

### To Renew:

```bash
# 1. Login again
aws sso login --profile devtest

# 2. Get new credentials
aws configure export-credentials --profile devtest --format env

# 3. Update GitHub secrets (all 3: KEY, SECRET, TOKEN)
# Go to: Settings → Secrets → Edit each one
```

---

## 💡 **Alternative: Get Credentials from AWS Console**

### Option 1: From Command Line

```bash
# After SSO login
export AWS_PROFILE=devtest
aws configure export-credentials --profile devtest
```

### Option 2: From AWS Console

1. **AWS Console** → Top right → Your name
2. **Command Line or programmatic access**
3. **Copy credentials:**
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - AWS_SESSION_TOKEN

---

## 🚀 Quick Setup Script

```bash
#!/bin/bash
# Get SSO credentials for GitHub

export AWS_PROFILE=devtest
aws sso login --profile devtest

echo "📋 Copy these to GitHub Secrets:"
echo ""
echo "AWS_ACCESS_KEY_ID:"
aws configure get aws_access_key_id --profile devtest
echo ""
echo "AWS_SECRET_ACCESS_KEY:"
aws configure get aws_secret_access_key --profile devtest
echo ""
echo "AWS_SESSION_TOKEN:"
aws configure get aws_session_token --profile devtest
echo ""
echo "⏰ These credentials expire in a few hours!"
echo "Renew by running: aws sso login --profile devtest"
```

---

## ⚠️ **Trade-offs**

### ✅ Pros (SSO Credentials):
- Quick to get
- Uses your existing SSO
- No need to create IAM user

### ❌ Cons (SSO Credentials):
- Expire in hours
- Need to update GitHub secrets regularly
- Pipeline fails when expired
- Not suitable for production

---

## 🎯 **For Your Challenge Demo**

**This is FINE for testing!**

### Workflow:

1. **Get SSO credentials** (as shown above)
2. **Add all 4 secrets to GitHub**
3. **Test pipeline** (push a commit)
4. **Renew when expired** (before next demo)

### Perfect for:
- ✅ Challenge demonstration
- ✅ Short-term testing
- ✅ Quick pipeline validation

### Not good for:
- ❌ Long-term CI/CD
- ❌ Production deployments
- ❌ Automated workflows

---

## 📝 Updated Secrets List

**Add to GitHub Repository Secrets:**

| Secret Name | Value | Notes |
|-------------|-------|-------|
| `DOCKERHUB_TOKEN` | Your Docker Hub token | Doesn't expire |
| `AWS_ACCESS_KEY_ID` | ASIA... | Expires in hours |
| `AWS_SECRET_ACCESS_KEY` | abc123... | Expires in hours |
| `AWS_SESSION_TOKEN` | IQoJb3... (very long) | Expires in hours |

---

## ✅ Summary

**YES, you can use SSO credentials for GitHub Actions!**

Just remember to:
1. Add all 4 secrets (including AWS_SESSION_TOKEN)
2. Renew them when they expire
3. Update all 3 AWS secrets in GitHub each time

**For a demo/challenge, this works perfectly!** 🚀

---

*Note: The workflow has been updated to accept AWS_SESSION_TOKEN*
