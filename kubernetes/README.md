# Kubernetes Manifests for SimpleTimeService

This directory contains Kubernetes manifests for deploying SimpleTimeService to EKS.

## Files

- `namespace.yaml` - Namespace configuration with Pod Security Standards
- `serviceaccount.yaml` - Service account with IRSA annotations
- `deployment.yaml` - Application deployment with 3 replicas
- `service.yaml` - NodePort service for ALB integration
- `hpa.yaml` - Horizontal Pod Autoscaler configuration
- `networkpolicy.yaml` - Network policies for zero-trust

## Deploy to EKS

### Prerequisites

```bash
# Configure kubectl
aws eks update-kubeconfig --name simpletimeservice-cluster --region us-west-1

# Verify connection
kubectl cluster-info
```

### Deploy Application

```bash
# Apply all manifests
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

# Or apply all at once
kubectl apply -f .
```

### Verify Deployment

```bash
# Check namespace
kubectl get namespace simpletimeservice

# Check pods
kubectl get pods -n simpletimeservice

# Check service
kubectl get svc -n simpletimeservice

# Check HPA
kubectl get hpa -n simpletimeservice

# View logs
kubectl logs -n simpletimeservice -l app=simpletimeservice --tail=50
```

### Update Image

```bash
# Update deployment with new image
kubectl set image deployment/simpletimeservice \
  simpletimeservice=anuddeeph1/simpletimeservice:v1.0.1 \
  -n simpletimeservice

# Check rollout status
kubectl rollout status deployment/simpletimeservice -n simpletimeservice

# View rollout history
kubectl rollout history deployment/simpletimeservice -n simpletimeservice
```

### Scale Application

```bash
# Manual scaling
kubectl scale deployment/simpletimeservice --replicas=5 -n simpletimeservice

# HPA will automatically scale based on CPU/Memory
# View HPA status
kubectl describe hpa simpletimeservice-hpa -n simpletimeservice
```

### Troubleshooting

```bash
# Describe pod
kubectl describe pod <pod-name> -n simpletimeservice

# View events
kubectl get events -n simpletimeservice --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs <pod-name> -n simpletimeservice

# Execute command in pod (distroless has no shell)
kubectl exec -it <pod-name> -n simpletimeservice -- /usr/local/bin/simpletimeservice --version

# Port forward for local testing
kubectl port-forward svc/simpletimeservice 8080:8080 -n simpletimeservice
```

### Delete Resources

```bash
# Delete all resources
kubectl delete -f .

# Or delete namespace (deletes everything)
kubectl delete namespace simpletimeservice
```

## Security Features

- **Non-root user**: Runs as UID 65532
- **Read-only root filesystem**: Prevents file modifications
- **Drop all capabilities**: Minimal Linux capabilities
- **Pod Security Standards**: Baseline enforcement
- **Security Context**: Enforced at pod and container level
- **Resource limits**: CPU and memory constraints
- **Network policies**: Zero-trust networking

## Resource Requirements

### Per Pod:
- **CPU Request**: 100m (0.1 cores)
- **CPU Limit**: 500m (0.5 cores)
- **Memory Request**: 64Mi
- **Memory Limit**: 256Mi

### Total (3 replicas):
- **CPU Request**: 300m
- **CPU Limit**: 1500m
- **Memory Request**: 192Mi
- **Memory Limit**: 768Mi

## Health Checks

- **Liveness Probe**: Checks if container is alive
- **Readiness Probe**: Checks if container is ready to serve traffic
- **Startup Probe**: Gives container time to start before liveness checks

All probes use `/health` endpoint.

## Auto-Scaling

HPA configuration:
- **Min Replicas**: 2
- **Max Replicas**: 10
- **CPU Target**: 70%
- **Memory Target**: 80%

Cluster Autoscaler will automatically add nodes when pods cannot be scheduled.

## License

MIT License

