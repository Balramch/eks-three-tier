# Three-Tier EKS Helm Chart

A production-ready Helm chart for deploying a three-tier Todo application on Amazon EKS.

## Chart Overview

This Helm chart provides templated Kubernetes manifests for:
- **Frontend**: React SPA (port 3000)
- **Backend**: Node.js/Express API (port 8080)
- **Database**: MongoDB (port 27017)
- **Ingress**: AWS ALB routing to frontend and backend
- **HPA**: Horizontal Pod Autoscaler for backend

## Directory Structure

```
three-tier/
├── Chart.yaml                          # Chart metadata
├── values.yaml                         # Default values
├── values/
│   ├── dev-values.yaml                # Development overlay
│   ├── staging-values.yaml            # Staging overlay
│   └── prod-values.yaml               # Production overlay
└── templates/
    ├── _helpers.tpl                   # Template helpers
    ├── deployment-backend.yaml        # Backend deployment
    ├── service-backend.yaml           # Backend service
    ├── deployment-frontend.yaml       # Frontend deployment
    ├── service-frontend.yaml          # Frontend service
    ├── mongo-deployment.yaml          # MongoDB deployment
    ├── mongo-service.yaml             # MongoDB service
    ├── secret-mongo.yaml              # MongoDB credentials secret
    ├── ingress.yaml                   # ALB ingress
    └── hpa-backend.yaml               # Backend autoscaler
```

## Quick Start

### 1. Verify Chart Syntax

```bash
helm lint ./three-tier
```

### 2. Dry Run (View Generated Manifests)

```bash
helm install my-todo ./three-tier \
  --namespace eks-test --create-namespace \
  --set "imagePullSecrets[0].name=ecr-secret" \
  --dry-run --debug
```

### 3. Install Release

```bash
helm install my-todo ./three-tier \
  --namespace eks-test --create-namespace \
  --set "imagePullSecrets[0].name=ecr-secret" \
  --set ingress.host=your-alb-dns.eu-central-1.elb.amazonaws.com
```

### 4. Verify Deployment

```bash
helm status my-todo -n eks-test
kubectl get all -n eks-test
```

## Configuration

### Default Values (values.yaml)

| Section | Key | Default |
|---------|-----|---------|
| `namespace` | — | `eks-test` |
| `backend.enabled` | — | `true` |
| `backend.replicas` | — | `1` |
| `backend.image.repository` | — | ECR backend image |
| `backend.image.tag` | — | `latest` |
| `backend.port` | — | `8080` |
| `backend.hpa.enabled` | — | `true` |
| `backend.hpa.minReplicas` | — | `1` |
| `backend.hpa.maxReplicas` | — | `10` |
| `backend.hpa.targetCPUUtilizationPercentage` | — | `50` |
| `frontend.enabled` | — | `true` |
| `frontend.replicas` | — | `1` |
| `frontend.image.repository` | — | ECR frontend image |
| `frontend.image.tag` | — | `latest` |
| `frontend.service.port` | — | `80` |
| `frontend.service.targetPort` | — | `3000` |
| `mongodb.enabled` | — | `true` |
| `mongodb.image` | — | `mongo:8.0.1` |
| `mongodb.port` | — | `27017` |
| `mongodb.auth.username` | — | `admin` |
| `mongodb.auth.password` | — | `password123` |
| `ingress.enabled` | — | `true` |
| `ingress.host` | — | `` (empty) |
| `imagePullSecrets` | — | `[]` |

### Environment-Specific Overlays

Use the provided `values/*.yaml` files to configure for different environments:

```bash
# Development (minimal resources)
helm install my-todo-dev ./three-tier \
  -n eks-test-dev --create-namespace \
  -f values/dev-values.yaml

# Staging (moderate resources, 2 replicas)
helm install my-todo-staging ./three-tier \
  -n eks-test-staging --create-namespace \
  -f values/staging-values.yaml

# Production (high availability, 3+ replicas, HPA, persistence)
helm install my-todo-prod ./three-tier \
  -n eks-test-prod --create-namespace \
  -f values/prod-values.yaml
```

### Common Customizations

#### Change Backend Image Tag

```bash
helm install my-todo ./three-tier \
  -n eks-test --create-namespace \
  --set backend.image.tag=v1.2.0 \
  --set frontend.image.tag=v1.2.0
```

#### Scale Backend Replicas

```bash
helm install my-todo ./three-tier \
  -n eks-test --create-namespace \
  --set backend.replicas=5
```

#### Set MongoDB Password Securely

```bash
helm install my-todo ./three-tier \
  -n eks-test --create-namespace \
  --set mongodb.auth.password="$(openssl rand -base64 32)"
```

#### Disable MongoDB (use external database)

```bash
helm install my-todo ./three-tier \
  -n eks-test --create-namespace \
  --set mongodb.enabled=false
```

#### Disable HPA

```bash
helm install my-todo ./three-tier \
  -n eks-test --create-namespace \
  --set backend.hpa.enabled=false
```

## Usage Examples

### Using Helm Deploy Script (Recommended)

```bash
# Install development environment
./helm-deploy.sh dev install --alb-host dev.example.com

# Upgrade staging with new image tag
./helm-deploy.sh staging upgrade --image-tag v2.0.0

# Perform dry run
./helm-deploy.sh prod install --dry-run

# Check production release status
./helm-deploy.sh prod status

# Uninstall development release
./helm-deploy.sh dev uninstall
```

### Using Helm CLI Directly

```bash
# Install with custom values
helm install my-todo ./three-tier \
  -f custom-values.yaml

# Upgrade release
helm upgrade my-todo ./three-tier \
  -f custom-values.yaml

# View generated manifests
helm template my-todo ./three-tier \
  -f custom-values.yaml

# Get release values
helm get values my-todo -n eks-test

# Rollback to previous version
helm rollback my-todo 1 -n eks-test
```

## Templating Features

### Conditional Components

All major components can be enabled/disabled:

```yaml
backend:
  enabled: true      # Deploy backend

frontend:
  enabled: true      # Deploy frontend

mongodb:
  enabled: true      # Deploy MongoDB

ingress:
  enabled: true      # Deploy ALB Ingress
```

### Dynamic Service Discovery

Backend deployment automatically discovers MongoDB:

```yaml
- name: MONGO_CONN_STR
  value: "mongodb://admin:password@{{ include "three-tier.fullname" . }}-mongodb:27017/..."
```

### Resource Management

Configure CPU/memory for each tier:

```yaml
backend:
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"
```

## Upgrade & Rollback

### Upgrade with New Values

```bash
helm upgrade my-todo ./three-tier \
  -n eks-test \
  --set backend.image.tag=v1.3.0 \
  --set backend.replicas=4
```

### View Release History

```bash
helm history my-todo -n eks-test
```

### Rollback to Specific Revision

```bash
helm rollback my-todo 2 -n eks-test  # Rollback to revision 2
```

## Troubleshooting

### Lint Chart for Errors

```bash
helm lint ./three-tier
```

### Template and Validate

```bash
helm template my-todo ./three-tier | kubectl apply -f - --dry-run=client
```

### View Computed Values

```bash
helm get values my-todo -n eks-test
helm get values my-todo -n eks-test --all  # Show defaults + overrides
```

### Render Specific Template

```bash
helm template my-todo ./three-tier -s templates/deployment-backend.yaml
```

## Uninstall

```bash
helm uninstall my-todo -n eks-test
```

## Best Practices

1. **Always use environment-specific values files** (dev/staging/prod)
2. **Manage sensitive values externally** — use `--set-file`, sealed-secrets, or Vault
3. **Test with `--dry-run` before installing** to prod
4. **Pin image tags** to specific versions in production
5. **Use GitOps** (ArgoCD, Flux) for repeatable deployments
6. **Version your chart** — update `Chart.yaml` when making changes
7. **Document overrides** in a separate values file per environment

## Support & Documentation

See [HELM_DEPLOYMENT.md](../../HELM_DEPLOYMENT.md) in the project root for comprehensive deployment guidance.

## License

Same as parent project.
