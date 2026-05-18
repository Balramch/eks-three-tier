# ArgoCD GitOps Extensions

This folder contains sample ArgoCD configuration for:

- `argocd-notifications`
- `argocd-image-updater`

## Usage

1. Install the controllers in the `argocd` namespace:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

2. Apply the sample config maps:

```bash
kubectl apply -f argocd/argocd-notifications-config.yaml
kubectl apply -f argocd/argocd-image-updater-config.yaml
```

3. Create secrets for SMTP email and repository write-back:

```bash
kubectl -n argocd create secret generic argocd-notifications-secret \
  --from-literal=email.username=<SMTP_USERNAME> \
  --from-literal=email.password=<SMTP_PASSWORD>

kubectl -n argocd create secret generic argocd-image-updater-repo-creds \
  --from-literal=username=<GIT_USERNAME> \
  --from-literal=password=<GIT_PASSWORD_OR_TOKEN>
```

4. Customize the ArgoCD Application annotations in `k8s_charts/three-tier/templates/argo-applications.yaml`.

## Notes

- `argocd-image-updater` needs access to your registry and git repository.
- `argocd-notifications` is configured here for SMTP email; update `recipients` in `argocd-notifications-config.yaml` to your email list.
- After installation, validate with `kubectl -n argocd get pods`.
