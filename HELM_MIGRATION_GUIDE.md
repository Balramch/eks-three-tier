# Migration Guide: From kubectl to Helm

This guide helps you migrate from managing individual Kubernetes manifests to using Helm.

## Before vs After

### Before: Manual kubectl Apply

```bash
# Create namespace
kubectl create namespace eks-test

# Apply each manifest individually
kubectl apply -f k8s_manifests/mongo/secrets.yaml
kubectl apply -f k8s_manifests/mongo/deploy.yaml
kubectl apply -f k8s_manifests/mongo/service.yaml
kubectl apply -f k8s_manifests/backend-deployment.yaml
kubectl apply -f k8s_manifests/backend-service.yaml
kubectl apply -f k8s_manifests/frontend-deployment.yaml
kubectl apply -f k8s_manifests/frontend-service.yaml
kubectl apply -f k8s_manifests/ingress.yaml
kubectl apply -f k8s_manifests/hpa.yaml

# Update something? Edit the YAML and reapply
# Rollback? Restore from git history and reapply
```

### After: Helm Release

```bash
# One command deploys everything
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test --create-namespace \
  --set "imagePullSecrets[0].name=ecr-secret"

# Update? Use helm upgrade
helm upgrade my-todo ./k8s_charts/three-tier --set backend.replicas=5

# Rollback? One command
helm rollback my-todo 1
```

---

## Migration Steps

### Step 1: Backup Current Deployments

```bash
# Export current manifests from cluster
kubectl get all -n eks-test -o yaml > eks-test-backup.yaml

# Save current configuration
helm template --debug ./k8s_manifests > current-manifests.yaml
```

### Step 2: Understand Values

Review `k8s_charts/three-tier/values.yaml` — every configurable value is listed there.

Compare with your old manifests:
- `backend.replicas` ← `spec.replicas` in `backend-deployment.yaml`
- `backend.image.tag` ← `image: ...eks-backend:TAG`
- `mongodb.auth.password` ← `data.password` in `mongo/secrets.yaml`

### Step 3: Create Custom Values

If your deployments differ from defaults, create a custom values file:

```bash
# For production environment
cat > my-production-values.yaml << EOF
namespace: eks-test
backend:
  replicas: 3
  image:
    tag: v1.0.0
mongodb:
  auth:
    password: MySecurePassword123
ingress:
  host: api.mycompany.com
EOF
```

### Step 4: Test with Dry Run

```bash
# Preview what Helm will deploy
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test --create-namespace \
  -f my-production-values.yaml \
  --dry-run --debug

# Compare with old kubectl approach
diff <(helm template my-todo ./k8s_charts/three-tier -f my-production-values.yaml) \
     <(kubectl get all -n eks-test -o yaml)
```

### Step 5: Deploy with Helm

```bash
# Option A: Fresh namespace (recommended for testing)
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test-helm --create-namespace \
  -f my-production-values.yaml

# Option B: Into existing namespace (requires coordination)
# ⚠️ WARNING: Only do this if no resources exist yet
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  -f my-production-values.yaml
```

### Step 6: Verify

```bash
# Check Helm release
helm status my-todo -n eks-test

# Verify pods are running
kubectl get pods -n eks-test
kubectl get svc -n eks-test
kubectl get ingress -n eks-test

# Test application
kubectl port-forward svc/frontend 3000:80 -n eks-test
# Open http://localhost:3000 in browser
```

### Step 7: Archive Old Manifests (Optional)

Keep old manifests for reference, but manage via Helm going forward:

```bash
# Archive old manifests
mkdir -p k8s_manifests_archive
mv k8s_manifests/* k8s_manifests_archive/
# or just leave them there as documentation
```

---

## Common Migration Scenarios

### Scenario A: Fresh EKS Cluster

**Easiest migration path:**

```bash
# 1. Skip kubectl—go straight to Helm
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test --create-namespace \
  -f values/prod-values.yaml

# 2. Done!
```

### Scenario B: Existing kubectl-managed Deployment

**Careful coordination needed:**

```bash
# 1. Backup existing
kubectl get all -n eks-test -o yaml > backup.yaml

# 2. Create Helm values matching current config
cat > current-values.yaml << EOF
backend:
  replicas: 1  # From kubectl deployment
  image:
    tag: latest
mongodb:
  auth:
    password: current-password
ingress:
  host: current-alb-dns.amazonaws.com
EOF

# 3. Test in separate namespace
helm install my-todo-test ./k8s_charts/three-tier \
  --namespace eks-test-helm \
  -f current-values.yaml \
  --dry-run

# 4. Once verified, delete old kubectl resources
kubectl delete deployment,svc,ingress -n eks-test -l app=my-app

# 5. Install Helm release in original namespace
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  -f current-values.yaml

# 6. Verify
kubectl get all -n eks-test
```

### Scenario C: Multi-Environment (dev/staging/prod)

**Deploy same chart to multiple environments:**

```bash
# Development
helm install my-todo-dev ./k8s_charts/three-tier \
  --namespace eks-test-dev --create-namespace \
  -f values/dev-values.yaml

# Staging
helm install my-todo-staging ./k8s_charts/three-tier \
  --namespace eks-test-staging --create-namespace \
  -f values/staging-values.yaml

# Production
helm install my-todo-prod ./k8s_charts/three-tier \
  --namespace eks-test-prod --create-namespace \
  -f values/prod-values.yaml

# List all releases
helm list --all-namespaces
```

---

## Updating Configuration

### Old Way: Edit YAML, Reapply

```bash
# 1. Edit manifest
nano k8s_manifests/backend-deployment.yaml
# Change replicas: 1 → replicas: 5

# 2. Reapply
kubectl apply -f k8s_manifests/backend-deployment.yaml

# 3. Verify
kubectl get deployment api -n eks-test
```

### New Way: Helm Upgrade

```bash
# 1. Update values or use --set
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.replicas=5

# 2. Done—Helm handles the rollout
helm status my-todo -n eks-test
```

---

## Rollback Strategy

### Old Way: Git Revert + Reapply

```bash
# 1. See what changed
git log --oneline k8s_manifests/

# 2. Revert
git checkout <old-commit> -- k8s_manifests/

# 3. Reapply
kubectl apply -f k8s_manifests/
```

### New Way: Helm Rollback

```bash
# 1. See deployment history
helm history my-todo -n eks-test

# 2. Rollback to previous
helm rollback my-todo 1 -n eks-test

# Done!
```

---

## Helm vs kubectl: Quick Reference

| Task | kubectl | Helm |
|------|---------|------|
| Initial Deploy | `kubectl apply -f manifest.yaml` | `helm install release chart/` |
| Update Config | Edit YAML + `kubectl apply -f` | `helm upgrade release chart/ --set key=value` |
| View Current State | `kubectl get ...` | `helm get values release` |
| Check Status | `kubectl describe pod ...` | `helm status release` |
| Rollback | Git revert + reapply | `helm rollback release 1` |
| View History | `git log` | `helm history release` |
| Delete | `kubectl delete -f manifest.yaml` | `helm uninstall release` |
| Template Testing | Manual inspection | `helm template release chart/` |
| Version Control | Manual tracking | Built-in revisions |

---

## Troubleshooting Migration

### Issue: "Resource already exists"

**Problem:** Trying to deploy Helm into namespace with existing resources.

**Solution:**
```bash
# Option 1: Use different namespace
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test-helm --create-namespace

# Option 2: Delete conflicting resources first
kubectl delete deployment,svc,ingress -n eks-test \
  -l role=api,role=frontend
```

### Issue: Helm values don't match cluster state

**Problem:** Your values file doesn't match what's currently deployed.

**Solution:**
```bash
# Export current cluster state
kubectl get all -n eks-test -o yaml > cluster-state.yaml

# Create values from cluster
# (manual step to extract key values)

# Verify with dry-run
helm install my-todo ./k8s_charts/three-tier \
  -f corrected-values.yaml \
  --dry-run --debug
```

### Issue: Pod not starting after migration

**Problem:** Configuration mismatch between Helm and kubectl deployments.

**Solution:**
```bash
# Compare generated manifests
helm template my-todo ./k8s_charts/three-tier > helm-manifest.yaml
kubectl get deployment api -o yaml -n eks-test > kubectl-manifest.yaml

# Diff them
diff helm-manifest.yaml kubectl-manifest.yaml

# Check pod logs
kubectl logs -l role=api -n eks-test
kubectl describe pod <pod-name> -n eks-test
```

---

## Best Practices During Migration

1. **Always backup before migrating**
   ```bash
   kubectl get all -n eks-test -o yaml > backup-$(date +%s).yaml
   ```

2. **Test in a separate namespace first**
   ```bash
   helm install my-todo-test ./k8s_charts/three-tier \
     --namespace test-migration \
     -f test-values.yaml
   ```

3. **Use `--dry-run` extensively**
   ```bash
   helm upgrade my-todo ./k8s_charts/three-tier \
     --set key=value \
     --dry-run --debug
   ```

4. **Document custom values**
   ```bash
   # my-environment-values.yaml
   # Values specific to my deployment
   # Reason for each override
   ```

5. **Keep Git history clean**
   ```bash
   # Commit both old manifests and new Helm chart
   git add k8s_manifests/ k8s_charts/
   git commit -m "Add Helm chart for three-tier app"
   ```

---

## After Migration: Next Steps

### 1. Set Up GitOps (Recommended)

```bash
# Use ArgoCD or Flux to sync Git → Kubernetes
# Benefits: Automatic rollbacks, audit trail, declarative config
```

### 2. Implement Helm Chart Testing

```bash
# Add `chart.test` subdirectory
# Define tests to validate chart renders correctly
```

### 3. Automate Deployments

```bash
# GitHub Actions / GitLab CI
# Trigger Helm upgrade on:
#   - Chart changes
#   - Image tag updates
#   - Configuration updates
```

### 4. Monitor Release History

```bash
# Regular review
helm history my-todo -n eks-test --max 20
```

---

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Hub](https://artifacthub.io/) — Search community charts
- [Helm Chart Template Guide](https://helm.sh/docs/chart_template_guide/)

---

**Happy Migrating! 🎉**
