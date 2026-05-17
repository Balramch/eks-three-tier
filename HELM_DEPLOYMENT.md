# Helm Deployment Guide – Three-Tier EKS Application

This guide walks you through deploying the three-tier application using the Helm chart.

## Prerequisites

- Helm 3.x installed
- kubectl configured and connected to your EKS cluster
- ECR repositories pushed with images: `eks-backend` and `eks-frontend`
- AWS ALB Ingress Controller installed in the cluster
- ECR secret (`ecr-secret`) created in the target namespace

## Quick Start

### 1. Create the Namespace

```bash
kubectl create namespace eks-test
```

### 2. Create ECR Pull Secret (if not exists)

```bash
kubectl create secret docker-registry ecr-secret \
  --docker-server=<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region <REGION>) \
  -n eks-test
```

### 3. Install the Helm Chart

#### Basic Install (with defaults)

```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set imagePullSecrets[0].name=ecr-secret
```

#### Install with Custom ALB Domain

```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set ingress.host=your-alb-dns.eu-central-1.elb.amazonaws.com \
  --set "imagePullSecrets[0].name=ecr-secret"
```

#### Install from Values File (Production)

```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  -f k8s_charts/three-tier/values/prod-values.yaml
```

## Configuration

### Common Value Overrides

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namespace` | `eks-test` | Kubernetes namespace |
| `backend.replicas` | `1` | Backend pod replicas |
| `backend.image.repository` | ECR backend image | Backend image URI |
| `backend.image.tag` | `latest` | Backend image tag |
| `frontend.image.repository` | ECR frontend image | Frontend image URI |
| `mongodb.auth.username` | `admin` | MongoDB root user |
| `mongodb.auth.password` | `password123` | MongoDB root password |
| `ingress.host` | `` | ALB DNS or domain |
| `ingress.enabled` | `true` | Enable ALB ingress |

### Override via CLI

```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.replicas=3 \
  --set "mongodb.auth.password=MySecurePassword!" \
  --set backend.image.tag=v1.2.0 \
  --set "imagePullSecrets[0].name=ecr-secret"
```

### Override via Values File

Create a custom values file (e.g., `custom-values.yaml`):

```yaml
namespace: eks-test

backend:
  replicas: 3
  image:
    tag: v1.2.0

frontend:
  replicas: 2

mongodb:
  auth:
    password: MySecurePassword!

ingress:
  host: app.example.com

imagePullSecrets:
  - name: ecr-secret
```

Install with custom values:

```bash
helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  -f custom-values.yaml
```

## Manage Secrets Securely

### Using External Secrets (Recommended for Production)

Instead of embedding MongoDB credentials in values, use `--set-file` or seal secrets:

```bash
echo -n "MySecurePassword" > /tmp/mongo-pass.txt

helm install my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set mongodb.auth.password="$(cat /tmp/mongo-pass.txt)" \
  --set "imagePullSecrets[0].name=ecr-secret"

rm /tmp/mongo-pass.txt
```

### Using sealed-secrets or HashiCorp Vault

Integrate with your secret management tool. The chart generates a Kubernetes Secret from `values.yaml`—ensure sensitive values come from your secret store, not the chart repo.

## Upgrade & Rollback

### Upgrade the Release

```bash
helm upgrade my-todo ./k8s_charts/three-tier \
  --namespace eks-test \
  --set backend.image.tag=v1.3.0 \
  --set "imagePullSecrets[0].name=ecr-secret"
```

### Rollback to Previous Release

```bash
helm rollback my-todo 1 -n eks-test
```

### View Release History

```bash
helm history my-todo -n eks-test
```

## Verify Deployment

### Check Release Status

```bash
helm status my-todo -n eks-test
```

### List All Resources

```bash
helm get values my-todo -n eks-test
helm get manifest my-todo -n eks-test
```

### Check Kubernetes Resources

```bash
kubectl get all -n eks-test
kubectl get ingress -n eks-test
kubectl describe ingress mainlb -n eks-test
```

### Get Application URL

```bash
kubectl get ingress mainlb -n eks-test -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Troubleshooting

### View Logs

```bash
# Backend logs
kubectl logs -n eks-test -l role=api --tail=50 -f

# Frontend logs
kubectl logs -n eks-test -l role=frontend --tail=50 -f

# MongoDB logs
kubectl logs -n eks-test -l app=mongodb --tail=50 -f
```

### Debug Pod

```bash
kubectl describe pod <pod-name> -n eks-test
kubectl exec -it <pod-name> -n eks-test -- /bin/sh
```

### Test Connectivity

```bash
# From any pod in the cluster
kubectl exec -it <backend-pod-name> -n eks-test -- curl http://mongodb-svc:27017

# Frontend to backend
kubectl exec -it <frontend-pod-name> -n eks-test -- curl http://api:8080/ok
```

## Uninstall

```bash
helm uninstall my-todo -n eks-test

# Clean up namespace
kubectl delete namespace eks-test
```

## Environment-Specific Deployments

Use overlay values files for dev, staging, and production:

```bash
# Development
helm install my-todo-dev ./k8s_charts/three-tier \
  -n eks-test-dev --create-namespace \
  -f k8s_charts/three-tier/values/dev-values.yaml

# Staging
helm install my-todo-staging ./k8s_charts/three-tier \
  -n eks-test-staging --create-namespace \
  -f k8s_charts/three-tier/values/staging-values.yaml

# Production
helm install my-todo-prod ./k8s_charts/three-tier \
  -n eks-test-prod --create-namespace \
  -f k8s_charts/three-tier/values/prod-values.yaml
```

## Next Steps

- Monitor with Prometheus/Grafana (already deployed via Terraform)
- Configure HPA for autoscaling based on custom metrics
- Set up GitOps with ArgoCD or Flux
- Implement CI/CD pipeline for automated deployments
