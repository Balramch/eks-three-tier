# Three-Tier Application on Amazon EKS

A production-grade, cloud-native **Todo application** deployed on **Amazon EKS** using a three-tier architecture — React frontend, Node.js/Express backend, and MongoDB database. Infrastructure is fully provisioned with **Terraform** and workloads are managed via **Kubernetes manifests** with **AWS ALB Ingress**, **HPA**, and **Prometheus/Grafana** monitoring.

---

## Architecture Overview

```
                        ┌─────────────────────────────────────┐
                        │           AWS Cloud (eu-central-1)  │
                        │                                      │
  Browser ──────────▶  │  ALB (internet-facing)               │
                        │    │                                 │
                        │    ├──/──────▶ Frontend (React:3000) │
                        │    │              ClusterIP :80      │
                        │    │                                 │
                        │    └──/api───▶ Backend (Node:8080)   │
                        │                   ClusterIP :8080    │
                        │                       │              │
                        │                  MongoDB :27017      │
                        │               (ClusterIP, eks-test)  │
                        └─────────────────────────────────────┘
```

**VPC Layout:**
- CIDR: `10.0.0.0/16`
- 2 Public Subnets + 2 Private Subnets across 2 AZs
- Single NAT Gateway
- EKS nodes deployed in private subnets

**EKS Node Groups:**
| Group | Instance | Capacity | Min/Max |
|-------|----------|----------|---------|
| general | t3.small | ON_DEMAND | 1 / 10 |
| spot | t3.micro | SPOT | 1 / 10 |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 17, Material UI, Axios |
| Backend | Node.js, Express 4, Mongoose 5 |
| Database | MongoDB 8.0.1 |
| Container Runtime | Docker |
| Orchestration | Kubernetes (Amazon EKS 1.25) |
| Infrastructure | Terraform |
| Ingress | AWS Load Balancer Controller (ALB) |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Autoscaling | Horizontal Pod Autoscaler (HPA) |
| Load Testing | Locust |
| Image Registry | Amazon ECR |

---

## Project Structure

```
.
├── app/
│   ├── backend/                  # Express REST API
│   │   ├── models/task.js
│   │   ├── routes/tasks.js
│   │   ├── db.js                 # MongoDB connection
│   │   ├── index.js              # App entrypoint
│   │   └── Dockerfile
│   └── frontend/                 # React SPA
│       ├── src/
│       │   ├── App.js
│       │   ├── Tasks.js
│       │   └── services/taskServices.js
│       └── Dockerfile
├── k8s_manifests/
│   ├── mongo/                    # MongoDB deployment, service, secrets
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── ingress.yaml              # AWS ALB Ingress
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   └── full_stack_lb.yaml
├── terraform/                    # Full AWS infrastructure as code
│   ├── vpc.tf
│   ├── eks.tf
│   ├── iam.tf
│   ├── monitoring.tf             # Prometheus/Grafana via Helm
│   ├── helm-load-balancer-controller.tf
│   ├── autoscaler-manifest.tf
│   └── variables.tf
├── kustomize/                    # Kustomize overlays (dev/staging/prod)
└── load_test/
    └── locustfile.py             # Locust load test
```

---

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with appropriate permissions
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/) with `buildx` support
- [Helm](https://helm.sh/docs/intro/install/) >= 3.x
- Amazon ECR repositories created for `eks-frontend` and `eks-backend`

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Balramch/eks-three-tier.git
cd eks-three-tier
```

### 2. Provision Infrastructure with Terraform

```bash
cd terraform

# Update variables as needed
cp variables.tf variables.tf.bak
# Edit cluster_name, region, availability_zones in variables.tf

terraform init
terraform plan
terraform apply
```

This provisions:
- VPC with public/private subnets
- EKS cluster with general (ON_DEMAND) and spot node groups
- IAM roles and IRSA
- AWS Load Balancer Controller
- Cluster Autoscaler
- EBS CSI Driver
- Prometheus + Grafana (kube-prometheus-stack)

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name>
kubectl get nodes
```

### 4. Build and Push Docker Images

**Backend:**
```bash
cd app/backend
aws ecr get-login-password --region <region> | docker login --username AWS \
  --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com

docker buildx build --platform linux/amd64 \
  -t <account_id>.dkr.ecr.<region>.amazonaws.com/eks-backend:latest .
docker push <account_id>.dkr.ecr.<region>.amazonaws.com/eks-backend:latest
```

**Frontend:**

> `REACT_APP_BACKEND_URL` is baked in at build time. Set it to your ALB DNS before building.

```bash
cd app/frontend
docker buildx build --platform linux/amd64 \
  --build-arg REACT_APP_BACKEND_URL=http://<alb-dns>/api/tasks \
  -t <account_id>.dkr.ecr.<region>.amazonaws.com/eks-frontend:latest .
docker push <account_id>.dkr.ecr.<region>.amazonaws.com/eks-frontend:latest
```

### 5. Deploy Kubernetes Manifests

```bash
# Create namespace
kubectl create namespace eks-test

# MongoDB
kubectl apply -f k8s_manifests/mongo/secrets.yaml
kubectl apply -f k8s_manifests/mongo/deploy.yaml
kubectl apply -f k8s_manifests/mongo/service.yaml

# Backend
kubectl apply -f k8s_manifests/backend-deployment.yaml
kubectl apply -f k8s_manifests/backend-service.yaml

# Frontend
kubectl apply -f k8s_manifests/frontend-deployment.yaml
kubectl apply -f k8s_manifests/frontend-service.yaml

# Ingress (ALB)
kubectl apply -f k8s_manifests/ingress.yaml

# HPA
kubectl apply -f k8s_manifests/hpa.yaml
```

### 6. Get the Application URL

```bash
kubectl get ingress -n eks-test
```

Access the app at the `ADDRESS` shown for the `mainlb` ingress.

---

## Environment Variables

### Backend

| Variable | Description | Example |
|----------|-------------|---------|
| `MONGO_CONN_STR` | Full MongoDB connection string | `mongodb://user:pass@mongodb-svc:27017/todo?authSource=admin` |
| `MONGO_USERNAME` | MongoDB username (from secret) | `admin` |
| `MONGO_PASSWORD` | MongoDB password (from secret) | — |
| `USE_DB_AUTH` | Enable MongoDB auth (`true`/`false`) | `true` |
| `PORT` | Server port | `8080` |

### Frontend (build-time)

| Variable | Description |
|----------|-------------|
| `REACT_APP_BACKEND_URL` | Full URL to backend `/api/tasks` endpoint |

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/ok` | Health check |
| GET | `/api/tasks` | List all tasks |
| POST | `/api/tasks` | Create a task |
| PUT | `/api/tasks/:id` | Update a task |
| DELETE | `/api/tasks/:id` | Delete a task |

---

## Monitoring

Prometheus and Grafana are deployed via Terraform using the `kube-prometheus-stack` Helm chart into the `prometheus` namespace.

```bash
# Access Grafana locally
kubectl port-forward svc/prometheus-grafana 3000:80 -n prometheus
```

Open `http://localhost:3000` — default credentials are `admin / prom-operator`.

---

## Autoscaling

HPA is configured for the backend `api` deployment:

| Setting | Value |
|---------|-------|
| Min replicas | 1 |
| Max replicas | 10 |
| CPU target | 50% |

```bash
kubectl get hpa -n eks-test
```

---

## Load Testing

[Locust](https://locust.io/) is used for load testing the frontend.

```bash
pip install locust
locust -f load_test/locustfile.py --host=http://<alb-dns>
```

Open `http://localhost:8089` to configure and start the load test.

---

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace eks-test

# Destroy infrastructure
cd terraform
terraform destroy
```

---

## Author
Balram Chaudhary
 DevOps | DevSecOps | Security Researcher | CTF Player

## Credit 
 @trainwithshubham
  
