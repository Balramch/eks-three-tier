# Helm Upgrade Summary – Three-Tier EKS Project

## Overview

Your three-tier EKS project has been **successfully converted to Helm-style deployment**. This provides:

✅ **Parameterized templates** for flexible, repeatable deployments  
✅ **Environment overlays** for dev, staging, and production  
✅ **Automated deployment script** for easy CLI management  
✅ **Production-ready configuration** with best practices  

---

## What Was Added

### 1. Helm Chart Structure

```
k8s_charts/three-tier/
├── Chart.yaml                 # Chart metadata (name, version, description)
├── README.md                  # Comprehensive chart documentation
├── values.yaml                # Default configuration values
├── values/                    # Environment-specific overlays
│   ├── dev-values.yaml       # Development (1 replica, low resources)
│   ├── staging-values.yaml   # Staging (2 replicas, moderate resources)
│   └── prod-values.yaml      # Production (3+ replicas, HPA, persistence)
└── templates/                # Kubernetes resource templates
    ├── _helpers.tpl          # Helper functions for labels/names
    ├── deployment-backend.yaml
    ├── service-backend.yaml
    ├── deployment-frontend.yaml
    ├── service-frontend.yaml
    ├── mongo-deployment.yaml
    ├── mongo-service.yaml
    ├── secret-mongo.yaml
    ├── ingress.yaml
    └── hpa-backend.yaml
```

### 2. Deployment Guides

- **[HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md)** — Complete deployment guide with examples
- **[k8s_charts/three-tier/README.md](./k8s_charts/three-tier/README.md)** — Helm chart documentation

### 3. Automation Script

- **[helm-deploy.sh](./helm-deploy.sh)** — Bash script for simplified deployment

---

## Key Features

### ✨ Parameterized Configuration

All critical values are configurable via `values.yaml`:

```yaml
namespace: eks-test
backend:
  replicas: 1
  image:
    repository: <ECR_REPO>/eks-backend
    tag: latest
  hpa:
    enabled: true
    minReplicas: 1
    maxReplicas: 10
mongodb:
  auth:
    username: admin
    password: password123
ingress:
  host: your-alb-dns.example.com
```

### 🌍 Environment-Specific Overlays

Deploy the same chart across environments with minimal configuration:

| Environment | Replicas | HPA | Resources | Use Case |
|-------------|----------|-----|-----------|----------|
| **dev** | 1 | ❌ | Minimal | Local testing |
| **staging** | 2 | ✅ (min:2, max:5) | Moderate | QA/testing |
| **prod** | 3 | ✅ (min:3, max:10) | High | Production |

### 🚀 Simplified Deployment

**Old way** (manage individual manifests):
```bash
kubectl apply -f k8s_manifests/mongo/secrets.yaml
kubectl apply -f k8s_manifests/mongo/deploy.yaml
kubectl apply -f k8s_manifests/backend-deployment.yaml
kubectl apply -f k8s_manifests/frontend-deployment.yaml
# ... etc
```

**New way** (single Helm command):
```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test --create-namespace \
  --set ingress.host=your-alb-dns \
  --set "imagePullSecrets[0].name=ecr-secret"
```

---

## Quick Start

### 1. **Verify the Chart**

```bash
helm lint ./k8s_charts/three-tier
```

### 2. **Dry Run (Preview Manifests)**

```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test --create-namespace \
  --set "imagePullSecrets[0].name=ecr-secret" \
  --dry-run --debug | head -50
```

### 3. **Install (Development)**

```bash
helm install my-todo-dev ./k8s_charts/three-tier \
  --namespace eks-test-dev --create-namespace \
  -f ./k8s_charts/three-tier/values/dev-values.yaml
```

### 4. **Install (Production)**

```bash
helm install my-todo-prod ./k8s_charts/three-tier \
  --namespace eks-test-prod --create-namespace \
  -f ./k8s_charts/three-tier/values/prod-values.yaml \
  --set mongodb.auth.password="$(openssl rand -base64 32)"
```

### 5. **Using the Automation Script**

```bash
# Install development
./helm-deploy.sh dev install --alb-host dev.example.com

# Upgrade staging
./helm-deploy.sh staging upgrade --image-tag v2.0.0

# Check production status
./helm-deploy.sh prod status

# Uninstall
./helm-deploy.sh dev uninstall
```

---

## Helm Commands Reference

| Command | Purpose |
|---------|---------|
| `helm lint` | Validate chart syntax |
| `helm template` | Render templates locally |
| `helm install` | Deploy a new release |
| `helm upgrade` | Update existing release |
| `helm rollback` | Revert to previous version |
| `helm status` | Check release status |
| `helm get values` | View current values |
| `helm uninstall` | Delete release |
| `helm history` | Show deployment history |

### Examples

```bash
# View rendered manifests
helm template my-todo ./k8s_charts/three-tier -f values-override.yaml

# See what changed without applying
helm diff upgrade my-todo ./k8s_charts/three-tier -n eks-test

# Get release history
helm history my-todo -n eks-test

# Rollback to previous revision
helm rollback my-todo 1 -n eks-test
```

---

## Configuration & Overrides

### Via CLI (`--set` flags)

```bash
helm install my-todo ./k8s_charts/three-tier \
  --set backend.replicas=5 \
  --set backend.image.tag=v1.2.0 \
  --set "mongodb.auth.password=SecurePass123!" \
  --set ingress.host=app.example.com
```

### Via Values File

```bash
# Create custom-values.yaml
backend:
  replicas: 5
  image:
    tag: v1.2.0

# Install with custom values
helm install my-todo ./k8s_charts/three-tier -f custom-values.yaml
```

### Merge Multiple Files

```bash
helm install my-todo ./k8s_charts/three-tier \
  -f values/prod-values.yaml \
  -f values-custom.yaml  # Overrides prod-values.yaml
```

---

## Secret Management (Production)

### ⚠️ Current Approach (Development Only)

MongoDB credentials are stored in `values.yaml`:

```yaml
mongodb:
  auth:
    username: admin
    password: password123  # ❌ NOT secure for production!
```

### ✅ Recommended for Production

**Option 1: Command-line Override**

```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set mongodb.auth.password="$(openssl rand -base64 32)"
```

**Option 2: External Secrets Operator**

```bash
# Using Sealed Secrets or HashiCorp Vault
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set-file mongodb.auth.password=/secrets/mongo-password.txt
```

**Option 3: AWS Secrets Manager**

Integrate with `external-secrets-operator`:

```yaml
# values-prod.yaml
mongodb:
  auth:
    password: "${AWS_SECRET:mongo-password}"  # Fetched at deployment time
```

---

## Troubleshooting

### Chart Won't Lint

```bash
helm lint ./k8s_charts/three-tier --debug
```

### YAML Parsing Errors (Fixed ✅)

**Previous Error:**
```
YAML parse error on three-tier/templates/deployment-backend.yaml: 
error converting YAML to JSON: yaml: line 19: block sequence entries are not allowed
```

**Root Cause:** Incorrect indentation with `toYaml` and `indent` functions.

**Solution:** Changed to use `nindent` for proper list indentation.

### Resources Not Deploying

```bash
# Check Helm release status
helm status my-todo -n eks-test

# View generated manifests
helm get manifest my-todo -n eks-test

# Check actual Kubernetes resources
kubectl describe deployment api -n eks-test
kubectl logs -l role=api -n eks-test
```

### MongoDB Connection Issues

```bash
# Test MongoDB connectivity from backend pod
kubectl exec -it <backend-pod> -n eks-test -- \
  curl mongodb-svc:27017

# Check MongoDB credentials
kubectl get secret my-todo-three-tier-mongo-secret -n eks-test -o yaml
```

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT }}:role/GitHubActions
          aws-region: eu-central-1
      
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --region eu-central-1 --name my-cluster
      
      - name: Helm Upgrade
        run: |
          helm upgrade my-todo ./k8s_charts/three-tier \
            --namespace eks-test \
            --set backend.image.tag=${{ github.sha }} \
            --set "mongodb.auth.password=${{ secrets.MONGO_PASSWORD }}"
```

---

## Next Steps

### 1. **Enable GitOps** (Recommended)
   - Use [ArgoCD](https://argoproj.github.io/cd/) or [Flux](https://fluxcd.io/)
   - Store Helm chart configurations in Git
   - Automatic sync on repository changes

### 2. **Implement Secret Management**
   - Set up [Sealed Secrets](https://sealed-secrets.netlify.app/) or [Vault](https://www.vaultproject.io/)
   - Remove plain-text passwords from repos

### 3. **Add Prometheus Rules**
   - Create PrometheusRule CRD for alerting
   - Configure Grafana dashboards

### 4. **Set Up Notifications**
   - Slack/Teams notifications on deployment
   - Helm hook for pre/post-deployment tasks

### 5. **Implement Helm Chart Testing**
   ```bash
   # Add chart tests
   mkdir -p k8s_charts/three-tier/tests
   # Create test manifests
   ```

---

## File Locations

| File/Directory | Purpose |
|---|---|
| [k8s_charts/three-tier/](./k8s_charts/three-tier/) | Main Helm chart |
| [k8s_charts/three-tier/Chart.yaml](./k8s_charts/three-tier/Chart.yaml) | Chart metadata |
| [k8s_charts/three-tier/values.yaml](./k8s_charts/three-tier/values.yaml) | Default values |
| [k8s_charts/three-tier/values/](./k8s_charts/three-tier/values/) | Environment overlays |
| [k8s_charts/three-tier/templates/](./k8s_charts/three-tier/templates/) | Kubernetes templates |
| [HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md) | Detailed deployment guide |
| [helm-deploy.sh](./helm-deploy.sh) | Automation script |

---

## Benefits of This Helm Upgrade

✅ **Reproducible Deployments** — Same code → same infrastructure, every time  
✅ **Environment Parity** — dev/staging/prod use identical chart, different values  
✅ **Version Control** — Track all configuration changes in Git  
✅ **Rollback Safety** — One command to revert to previous version  
✅ **Team Collaboration** — Clear values files for different teams  
✅ **CI/CD Integration** — Easily integrate with automation pipelines  
✅ **Production Ready** — HPA, monitoring, resource limits all configured  

---

## Support

For detailed deployment instructions, see:
- [HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md) — Comprehensive guide
- [k8s_charts/three-tier/README.md](./k8s_charts/three-tier/README.md) — Chart documentation
- [Helm Official Docs](https://helm.sh/docs/)

---

**Happy Helming! 🚀**
