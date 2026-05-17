# Helm Deployment Quick Reference

**Your project has been upgraded to Helm! Here's what you need to know.**

## 📋 Quick Links

| Document | Purpose |
|----------|---------|
| [HELM_UPGRADE_SUMMARY.md](./HELM_UPGRADE_SUMMARY.md) | Complete overview of changes |
| [HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md) | Step-by-step deployment guide |
| [HELM_MIGRATION_GUIDE.md](./HELM_MIGRATION_GUIDE.md) | Migrate from kubectl to Helm |
| [k8s_charts/three-tier/README.md](./k8s_charts/three-tier/README.md) | Helm chart documentation |

---

## 🚀 Quick Start (Copy & Paste)

### 1. First-Time Setup

```bash
# From project root
cd /Users/balram/Devsecops/github.com/three-tier-eks-project

# Verify chart is valid
helm lint ./k8s_charts/three-tier

# Preview manifests
helm template my-todo ./k8s_charts/three-tier --dry-run
```

### 2. Deploy to Development

```bash
./helm-deploy.sh dev install \
  --alb-host dev-alb.eu-central-1.elb.amazonaws.com
```

### 3. Deploy to Staging

```bash
./helm-deploy.sh staging install \
  --alb-host staging-alb.eu-central-1.elb.amazonaws.com
```

### 4. Deploy to Production

```bash
./helm-deploy.sh prod install \
  --alb-host api.example.com
```

---

## 📁 New Helm Chart Structure

```
k8s_charts/three-tier/
├── Chart.yaml                 ← Chart metadata
├── values.yaml                ← Default configuration
├── README.md                  ← Chart docs
├── values/                    ← Environment overlays
│   ├── dev-values.yaml       ← Dev config
│   ├── staging-values.yaml   ← Staging config
│   └── prod-values.yaml      ← Production config
└── templates/                 ← Kubernetes templates
    ├── _helpers.tpl
    ├── deployment-backend.yaml
    ├── deployment-frontend.yaml
    ├── mongo-*.yaml
    ├── service-*.yaml
    ├── ingress.yaml
    └── hpa-backend.yaml
```

---

## 🎯 Most Common Commands

### Deployment

```bash
# Install
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test --create-namespace \
  --set "imagePullSecrets[0].name=ecr-secret" \
  --set ingress.host=your-alb-dns.amazonaws.com

# Upgrade (change configuration)
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.replicas=5

# Rollback (undo last change)
helm rollback my-todo -n eks-test
```

### Monitoring

```bash
# Check status
helm status my-todo -n eks-test

# View values being used
helm get values my-todo -n eks-test

# See deployment history
helm history my-todo -n eks-test

# View actual manifests
helm get manifest my-todo -n eks-test
```

### Troubleshooting

```bash
# Validate chart syntax
helm lint ./k8s_charts/three-tier

# Test render (no deployment)
helm template my-todo ./k8s_charts/three-tier \
  -f custom-values.yaml

# Check Kubernetes resources
kubectl get all -n eks-test
kubectl describe pod <pod-name> -n eks-test
kubectl logs <pod-name> -n eks-test
```

---

## 🔧 Common Configuration Changes

### Change Backend Replicas

```bash
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.replicas=5
```

### Change Image Tag

```bash
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.image.tag=v2.0.0 \
  --set frontend.image.tag=v2.0.0
```

### Change MongoDB Password

```bash
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set mongodb.auth.password="NewSecurePassword!"
```

### Disable HPA (Horizontal Pod Autoscaler)

```bash
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.hpa.enabled=false
```

### Use Custom Values File

```bash
# Create my-values.yaml with your settings
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  -f my-values.yaml
```

---

## 🔐 Security Checklist

- [ ] Update MongoDB password from `password123` (see [HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md#using-external-secrets-recommended-for-production))
- [ ] Create ECR secret: `kubectl create secret docker-registry ecr-secret ...`
- [ ] Use `--set-file` or secrets manager for sensitive values (not in Git!)
- [ ] Configure image pull policies to `IfNotPresent` in production
- [ ] Enable network policies if required
- [ ] Review resource limits for backend/frontend

---

## 📊 Environment Configuration

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| Namespace | eks-test-dev | eks-test-staging | eks-test-prod |
| Replicas | 1 | 2 | 3 |
| HPA | ❌ | ✅ | ✅ |
| CPU Request | 50m | 100m | 200m |
| Memory Request | 64Mi | 128Mi | 256Mi |
| Image Pull Policy | Always | IfNotPresent | IfNotPresent |
| MongoDB Persistence | ❌ | ❌ | ✅ |

---

## 🔄 Upgrade & Rollback Examples

### Scenario: Deploy New Backend Version

```bash
# 1. Verify the new version works
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.image.tag=v2.0.0 \
  --dry-run --debug

# 2. If looks good, apply it
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.image.tag=v2.0.0

# 3. Monitor
helm status my-todo -n eks-test
kubectl get pods -n eks-test -w

# 4. If issues, rollback
helm rollback my-todo -n eks-test
```

### Scenario: Scale Backend to Handle Load

```bash
# Check current replicas
kubectl get deployment api -n eks-test

# Scale up
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.replicas=5

# Verify
kubectl get deployment api -n eks-test
```

---

## ❓ FAQ

### Q: Where are my old manifests?
**A:** They're still in `k8s_manifests/` for reference. New deployments use the Helm chart in `k8s_charts/three-tier/`.

### Q: Can I keep using kubectl apply?
**A:** ⚠️ Not recommended with Helm. Helm manages the release lifecycle. Stick with `helm install/upgrade/rollback`.

### Q: How do I deploy multiple instances?
**A:** Use different release names and namespaces:
```bash
helm install my-todo-prod ./k8s_charts/three-tier -n prod
helm install my-todo-dev ./k8s_charts/three-tier -n dev
```

### Q: Can I modify the chart?
**A:** Yes! Values in `values.yaml` are meant to be customized. Edit `templates/` carefully.

### Q: How do I update the chart version?
**A:** Edit `Chart.yaml`:
```yaml
version: 0.2.0  # Increment this
appVersion: "2.0.0"  # Your app version
```

### Q: Can I use Helm with ArgoCD?
**A:** Yes! ArgoCD natively supports Helm charts. See [HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md#integration-with-cicd).

---

## 📚 Learn More

- **Helm Basics:** [helm.sh/docs](https://helm.sh/docs/)
- **Chart Best Practices:** [helm.sh/docs/chart_best_practices](https://helm.sh/docs/chart_best_practices/)
- **Helm Chart Hub:** [artifacthub.io](https://artifacthub.io/)
- **Your Detailed Guides:**
  - [HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md) — Full deployment guide
  - [HELM_MIGRATION_GUIDE.md](./HELM_MIGRATION_GUIDE.md) — Migrating from kubectl
  - [HELM_UPGRADE_SUMMARY.md](./HELM_UPGRADE_SUMMARY.md) — What changed

---

## ⚠️ Breaking Changes from Old Setup

| Old Way | New Way | Impact |
|---------|---------|--------|
| `kubectl apply -f k8s_manifests/` | `helm install` | Must use Helm for deployments |
| Edit YAML + reapply | Use values overrides | Values take precedence |
| Manual rollback via Git | `helm rollback` | Much faster, safer |
| Namespace management varies | Helm handles with `--create-namespace` | Consistent setup |

---

## 🎯 Next Steps

1. **Read [HELM_UPGRADE_SUMMARY.md](./HELM_UPGRADE_SUMMARY.md)** for a detailed overview
2. **Follow [HELM_DEPLOYMENT.md](./HELM_DEPLOYMENT.md)** for step-by-step instructions
3. **Deploy to dev/staging** for testing
4. **Move production workloads** (follow [HELM_MIGRATION_GUIDE.md](./HELM_MIGRATION_GUIDE.md))
5. **Set up GitOps** (ArgoCD/Flux for automated syncs)

---

## 🆘 Need Help?

- **Chart not linting?** → `helm lint ./k8s_charts/three-tier --debug`
- **Want to preview manifests?** → `helm template my-todo ./k8s_charts/three-tier`
- **Pods not starting?** → `kubectl logs <pod-name> -n eks-test`
- **Need to rollback?** → `helm rollback my-todo 1 -n eks-test`

---

**Happy Helming! 🚀**

For questions, see the comprehensive guides linked above.
