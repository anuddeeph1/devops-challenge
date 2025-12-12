# ALB Alternatives Guide

## Why Do We Need a Load Balancer?

The Application Load Balancer (ALB) serves as the **public gateway** to your application running in private EKS subnets.

### Current Architecture (With ALB)

```
Internet
   ↓
Application Load Balancer (Public Subnets)
   ↓ Port 30080
EKS Nodes (Private Subnets)
   ↓ Port 8080
Pods (simpletimeservice)
```

**Cost**: ~$164/month (includes $17-23 for ALB)

---

## 🎯 Alternative Architectures

### Option 1: Public Nodes + NodePort (No ALB) ⭐ RECOMMENDED FOR DEMO

**Architecture**:
```
Internet
   ↓ NodePort 30080
EKS Nodes (Public Subnets) ← Direct public IP
   ↓ Port 8080
Pods (simpletimeservice)
```

**Implementation**:
```hcl
# In terraform/main.tf, change:
module "eks" {
  ...
  subnet_ids = module.vpc.public_subnets  # Instead of private_subnets
}
```

**Access**: `http://<node-public-ip>:30080/`

**Pros**:
- ✅ Saves $17-23/month
- ✅ Simpler architecture
- ✅ Direct access
- ✅ Good for demos

**Cons**:
- ❌ Less secure (nodes exposed)
- ❌ No automatic load balancing
- ❌ Not production-ready

**Cost**: **~$140/month**

---

### Option 2: Kubernetes LoadBalancer Service (NLB)

**Architecture**:
```
Internet
   ↓
Network Load Balancer (AWS Auto-Created)
   ↓
EKS Nodes (Private Subnets)
   ↓
Pods (simpletimeservice)
```

**Implementation**:
```yaml
# kubernetes/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: simpletimeservice
spec:
  type: LoadBalancer  # ← Change from NodePort
  selector:
    app: simpletimeservice
  ports:
  - port: 80
    targetPort: 8080
```

**Access**: Auto-generated NLB DNS name

**Pros**:
- ✅ Kubernetes-native
- ✅ Automatic LB creation
- ✅ Nodes stay private
- ✅ Layer 4 load balancing

**Cons**:
- ❌ Still costs $16-18/month (NLB)
- ❌ Less features than ALB
- ❌ No path-based routing

**Cost**: **~$162/month**

---

### Option 3: NGINX Ingress Controller

**Architecture**:
```
Internet
   ↓
Network Load Balancer (AWS Auto-Created)
   ↓
NGINX Ingress Controller (Pod)
   ↓
Service → Pods
```

**Implementation**:
```bash
# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml

# Create Ingress resource
kubectl apply -f kubernetes/ingress.yaml
```

**Pros**:
- ✅ Advanced routing (path, host-based)
- ✅ SSL termination
- ✅ Multiple apps per LB
- ✅ More control

**Cons**:
- ❌ Still needs NLB (~$16/month)
- ❌ More complex
- ❌ Additional pod overhead

**Cost**: **~$162/month**

---

### Option 4: No Load Balancer (Port Forward Only)

**Architecture**:
```
Your Machine
   ↓ kubectl port-forward
EKS API Server
   ↓
Pods (simpletimeservice)
```

**Implementation**:
```bash
# Port forward from your machine
kubectl port-forward svc/simpletimeservice 8080:8080 -n simpletimeservice

# Access at localhost
curl http://localhost:8080/
```

**Pros**:
- ✅ **FREE!** No LB costs
- ✅ Simplest for testing
- ✅ Secure (no public exposure)

**Cons**:
- ❌ Only accessible from your machine
- ❌ Not publicly accessible
- ❌ Requires kubectl/VPN
- ❌ Can't demo to others remotely

**Cost**: **~$140/month**

---

## 💰 Cost Comparison

| Architecture | Monthly Cost | Public Access | HA | Security | Best For |
|--------------|--------------|---------------|----|-----------|----|
| **ALB (Current)** | **$164** | ✅ Yes | ✅ Yes | ✅ Best | Production |
| **Public Nodes** | **$140** | ✅ Yes | ❌ No | ⚠️ Medium | Demo/Dev |
| **NLB (K8s LB)** | **$162** | ✅ Yes | ✅ Yes | ✅ Good | Production |
| **NGINX Ingress** | **$162** | ✅ Yes | ✅ Yes | ✅ Good | Production |
| **Port Forward** | **$140** | ❌ No | N/A | ✅ Best | Local Dev |

---

## 🎯 Recommendations

### For Challenge Demo (Save Money)

**Use Option 1: Public Nodes (No ALB)**

Why:
- Saves $24/month
- Still publicly accessible
- Simple architecture
- Good enough for demo

Drawbacks are acceptable for a challenge demo:
- Single node is fine (not running at scale)
- Security is less critical (temporary deployment)
- Can destroy after demo

### For Production

**Keep ALB or use NGINX Ingress**

Why:
- Proper security (nodes in private subnets)
- Load balancing across multiple nodes
- Health checks
- SSL termination ready
- Professional setup

---

## 🔧 How to Switch Configurations

### To Remove ALB (Public Nodes)

**Step 1**: Modify `terraform/main.tf`

```hcl
# Find this section in main.tf
module "eks" {
  ...
  # Change this line:
  subnet_ids = module.vpc.private_subnets
  
  # To:
  subnet_ids = module.vpc.public_subnets
}
```

**Step 2**: Comment out ALB resources in `terraform/alb.tf`

```hcl
# Comment out or delete entire alb.tf file
# Or use terraform -target to exclude it
```

**Step 3**: Get node public IP after deployment

```bash
# Get node public IP
kubectl get nodes -o wide

# Access application
curl http://<NODE-EXTERNAL-IP>:30080/
```

### To Use Kubernetes LoadBalancer

**Step 1**: Keep current Terraform (nodes in private subnets)

**Step 2**: Change Service type

```yaml
# kubernetes/service.yaml
spec:
  type: LoadBalancer  # Change from NodePort
```

**Step 3**: Deploy and get LB DNS

```bash
kubectl apply -f kubernetes/service.yaml

# Get Load Balancer URL
kubectl get svc simpletimeservice -n simpletimeservice

# Access application
curl http://<EXTERNAL-IP>/
```

---

## ⚖️ Decision Matrix

### Choose ALB If:
- [ ] Production environment
- [ ] Need advanced routing
- [ ] Want WAF integration
- [ ] Multiple applications
- [ ] SSL termination at LB

### Choose Public Nodes If:
- [x] Demo/Challenge submission ⭐
- [x] Cost is primary concern
- [x] Temporary deployment
- [x] Simple architecture
- [x] Single application

### Choose Kubernetes LB If:
- [ ] Want Kubernetes-native solution
- [ ] Don't need ALB features
- [ ] Simple load balancing
- [ ] Nodes should stay private

### Choose Port Forward If:
- [ ] Local development only
- [ ] Testing before public deployment
- [ ] No public access needed
- [ ] Maximum security

---

## 📊 Real-World Usage

### Small Startup
- Start: Port Forward / Public Nodes
- Cost: ~$140/month
- Good for MVP

### Growing Company
- Use: Kubernetes LoadBalancer or NGINX Ingress
- Cost: ~$162/month
- Handles moderate traffic

### Enterprise
- Use: ALB with WAF, multiple rules
- Cost: ~$164+ (plus WAF)
- Production-grade

---

## 🎓 For Your Challenge

**My Recommendation**: Keep the ALB for now because:

1. ✅ **Shows proper architecture** knowledge
2. ✅ **Production-ready** setup
3. ✅ **Security best practices** (private subnets)
4. ✅ **Load balancing** across nodes
5. ✅ **Impresses reviewers** more than public nodes

**If Cost is Critical**: Use public nodes (saves $24/month)

**Compromise**: Deploy with ALB, demo it, then destroy immediately
- Deploy: 2-3 hours
- Total cost: ~$0.50-$0.70
- Best of both worlds!

---

## 🚀 Quick Reference

```bash
# Current setup (WITH ALB)
Monthly: $164
Access: http://<alb-dns>/

# Without ALB (Public Nodes)
Monthly: $140
Access: http://<node-ip>:30080/

# With K8s LoadBalancer
Monthly: $162
Access: http://<lb-dns>/

# Port Forward Only
Monthly: $140
Access: http://localhost:8080/ (local only)
```

---

**Bottom Line**: For a professional challenge submission showing DevOps expertise, **keep the ALB**. The extra $24/month demonstrates you understand production architectures. Just destroy it quickly after demo! 🎯

