# SimpleTimeService Helm Chart

A Helm chart for deploying SimpleTimeService microservice to Kubernetes.

## Installation

### Install with default values

```bash
helm install simpletimeservice ./helm-chart -n simpletimeservice --create-namespace
```

### Install with custom values

```bash
helm install simpletimeservice ./helm-chart \
  -n simpletimeservice \
  --create-namespace \
  --set image.tag=v1.0.0 \
  --set replicaCount=5
```

### Install with custom values file

```bash
helm install simpletimeservice ./helm-chart \
  -n simpletimeservice \
  --create-namespace \
  -f custom-values.yaml
```

## Upgrade

```bash
helm upgrade simpletimeservice ./helm-chart -n simpletimeservice
```

## Uninstall

```bash
helm uninstall simpletimeservice -n simpletimeservice
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Docker image repository | `anuddeeph1/simpletimeservice` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `replicaCount` | Number of replicas | `3` |
| `service.type` | Service type | `NodePort` |
| `service.port` | Service port | `8080` |
| `service.nodePort` | NodePort number | `30080` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `64Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Min replicas | `2` |
| `autoscaling.maxReplicas` | Max replicas | `10` |

## Values

See `values.yaml` for all configuration options.

## Testing

```bash
# Test template rendering
helm template simpletimeservice ./helm-chart

# Dry run
helm install simpletimeservice ./helm-chart --dry-run --debug

# Lint chart
helm lint ./helm-chart
```

