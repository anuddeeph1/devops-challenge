# Kyverno Pod Security Policies

This directory contains Kyverno policies for enforcing Pod Security Standards.

## Overview

**Total Policies**: 7  
**Baseline**: 4 policies  
**Restricted**: 3 policies  
**Mode**: Audit (recommended to start)

## Policies

### Baseline Pod Security Standards (4 policies)

| Policy | Severity | Description |
|--------|----------|-------------|
| `disallow-privileged-containers` | High | Prevents privileged mode |
| `disallow-host-namespaces` | High | Blocks host namespace access |
| `disallow-host-path` | Medium | Prevents hostPath volumes |
| `disallow-host-ports` | Medium | Blocks host port usage |

### Restricted Pod Security Standards (3 policies)

| Policy | Severity | Description |
|--------|----------|-------------|
| `require-run-as-nonroot` | Medium | Enforces non-root execution |
| `disallow-privilege-escalation` | Medium | Prevents privilege escalation |
| `restrict-capabilities` | Medium | Requires dropping ALL capabilities |

## Scan Results for SimpleTimeService

### ✅ Compliance Status

```
Baseline Policies:  4/4 PASS ✅
Restricted Policies: 3/3 PASS ✅

Total: 7 policies, 0 violations
```

**SimpleTimeService is fully compliant with Pod Security Standards!**

## Usage

### Local Scanning with Kyverno CLI

```bash
# Scan Helm chart
./scripts/kyverno-scan.sh

# View reports
cat kyverno-reports/summary.md
cat kyverno-reports/baseline-report.txt
cat kyverno-reports/restricted-report.txt
```

### CI/CD Integration

The Kyverno scan runs automatically in GitHub Actions:

```yaml
Trigger: Push or PR to main
Workflow: .github/workflows/kyverno-scan.yaml
```

**Reports are uploaded as artifacts** (30 days retention)

### Manual Scanning

```bash
# Install Kyverno CLI
brew install kyverno

# Or download binary
wget https://github.com/kyverno/kyverno/releases/download/v1.12.0/kyverno-cli_v1.12.0_darwin_arm64.tar.gz

# Render Helm templates
helm template simpletimeservice ./kubernetes/helm-chart > /tmp/manifests.yaml

# Scan with baseline policies
kyverno apply kubernetes/kyverno-policies/baseline/ --resource /tmp/manifests.yaml

# Scan with restricted policies
kyverno apply kubernetes/kyverno-policies/restricted/ --resource /tmp/manifests.yaml

# Scan standalone manifests
kyverno apply kubernetes/kyverno-policies/ --resource kubernetes/deployment.yaml
```

## Policy Details

### Baseline: disallow-privileged-containers

**What it checks:**
- `spec.containers[*].securityContext.privileged` must be `false`
- `spec.initContainers[*].securityContext.privileged` must be `false`

**Why it matters:**
- Privileged containers have root access to host
- Can access all devices
- Major security risk

**SimpleTimeService compliance:** ✅ PASS (not using privileged mode)

### Baseline: disallow-host-namespaces

**What it checks:**
- `spec.hostNetwork` must be `false`
- `spec.hostPID` must be `false`
- `spec.hostIPC` must be `false`

**Why it matters:**
- Host namespaces allow access to host processes
- Can snoop on other containers
- Security isolation breach

**SimpleTimeService compliance:** ✅ PASS (isolated namespaces)

### Baseline: disallow-host-path

**What it checks:**
- `spec.volumes[*].hostPath` must not be set

**Why it matters:**
- Host path volumes access host filesystem
- Can read sensitive files
- Privilege escalation risk

**SimpleTimeService compliance:** ✅ PASS (no hostPath volumes)

### Baseline: disallow-host-ports

**What it checks:**
- `spec.containers[*].ports[*].hostPort` must be 0 or unset

**Why it matters:**
- Host ports can conflict
- Bypass network policies
- Security risk

**SimpleTimeService compliance:** ✅ PASS (no host ports)

### Restricted: require-run-as-nonroot

**What it checks:**
- `spec.securityContext.runAsNonRoot` is `true`  
  OR  
- All containers have `securityContext.runAsNonRoot: true`

**Why it matters:**
- Running as root is major security risk
- Container escape scenarios
- Privilege abuse

**SimpleTimeService compliance:** ✅ PASS (runs as UID 65532)

### Restricted: disallow-privilege-escalation

**What it checks:**
- `spec.containers[*].securityContext.allowPrivilegeEscalation` must be `false`

**Why it matters:**
- Prevents setuid binaries
- Blocks privilege gain
- Defense in depth

**SimpleTimeService compliance:** ✅ PASS (explicitly disabled)

### Restricted: restrict-capabilities

**What it checks:**
- `spec.containers[*].securityContext.capabilities.drop` must include `ALL`

**Why it matters:**
- Linux capabilities grant specific privileges
- Should drop all unless needed
- Minimal attack surface

**SimpleTimeService compliance:** ✅ PASS (drops ALL capabilities)

## Enforcement Modes

### Current: Audit Mode
```yaml
validationFailureAction: Audit
```

**Behavior:**
- Logs policy violations
- Allows non-compliant resources
- Good for testing and migration

### Production: Enforce Mode
```yaml
validationFailureAction: Enforce
```

**Behavior:**
- Blocks non-compliant resources
- Prevents deployment of violations
- Recommended for production

**To enable**: Edit each policy file and change `Audit` to `Enforce`

## Scan in CI/CD

### GitHub Actions Workflow

File: `.github/workflows/kyverno-scan.yaml`

**Triggers:**
- Push to main/develop
- Pull requests
- Manual trigger

**Actions:**
1. Install Kyverno CLI
2. Render Helm templates
3. Scan with baseline policies
4. Scan with restricted policies
5. Upload reports
6. Comment on PR (if applicable)

**Artifacts:**
- `kyverno-scan-reports` (30 days)
  - baseline-report.txt
  - restricted-report.txt
  - summary.md

## Integration with Terraform

To deploy Kyverno to the cluster and enforce policies at runtime:

```hcl
# Add to terraform/main.tf
resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  namespace  = "kyverno"
  create_namespace = true

  set {
    name  = "replicaCount"
    value = "3"
  }
}

# Deploy policies
resource "kubectl_manifest" "kyverno_policies" {
  for_each  = fileset("${path.module}/../kubernetes/kyverno-policies", "**/*.yaml")
  yaml_body = file("${path.module}/../kubernetes/kyverno-policies/${each.value}")

  depends_on = [helm_release.kyverno]
}
```

## Benefits

- ✅ Automated security validation
- ✅ Prevents misconfigurations
- ✅ Compliance verification
- ✅ CI/CD integration
- ✅ No manual review needed
- ✅ Continuous monitoring

## References

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Kyverno CLI](https://kyverno.io/docs/kyverno-cli/)

---

**Your application passes all Pod Security Standards!** 🏆

