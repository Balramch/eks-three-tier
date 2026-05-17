#!/bin/bash

# Helm Deployment Script for Three-Tier EKS Application
# Usage: ./helm-deploy.sh [dev|staging|prod] [install|upgrade|uninstall]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHART_PATH="./k8s_charts/three-tier"
RELEASE_NAME="my-todo"
ACCOUNT_ID="011528274726"
REGION="eu-central-1"

# Function to print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [ACTION] [OPTIONS]

ENVIRONMENT:
  dev       - Development environment
  staging   - Staging environment
  prod      - Production environment

ACTION:
  install   - Install the Helm release
  upgrade   - Upgrade an existing release
  uninstall - Uninstall the release
  status    - Show release status
  values    - Show computed values

OPTIONS:
  --alb-host HOST     - ALB DNS or domain name
  --image-tag TAG     - Override image tag (default: env tag)
  --replicas N        - Override backend replicas
  --dry-run           - Perform a dry run
  --help              - Show this message

Examples:
  $0 dev install --alb-host dev.example.com
  $0 prod upgrade --image-tag v1.2.0
  $0 staging install --dry-run
EOF
    exit 1
}

# Parse arguments
ENVIRONMENT="${1:-}"
ACTION="${2:-}"

if [[ -z "$ENVIRONMENT" ]] || [[ -z "$ACTION" ]]; then
    usage
fi

case "$ENVIRONMENT" in
    dev|staging|prod)
        NAMESPACE="eks-test-${ENVIRONMENT}"
        VALUES_FILE="${CHART_PATH}/values/${ENVIRONMENT}-values.yaml"
        ;;
    *)
        log_error "Invalid environment: $ENVIRONMENT"
        usage
        ;;
esac

if [[ ! -f "$VALUES_FILE" ]]; then
    log_error "Values file not found: $VALUES_FILE"
    exit 1
fi

# Parse optional arguments
DRY_RUN=""
ALB_HOST=""
IMAGE_TAG=""
REPLICAS=""

shift 2  # Move past ENVIRONMENT and ACTION
while [[ $# -gt 0 ]]; do
    case $1 in
        --alb-host)
            ALB_HOST="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --replicas)
            REPLICAS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="--dry-run=client"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Ensure ECR secret exists
ensure_ecr_secret() {
    log_info "Checking ECR secret in namespace $NAMESPACE..."
    if ! kubectl get secret ecr-secret -n "$NAMESPACE" &>/dev/null; then
        log_warning "ECR secret not found. Creating..."
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
        
        local password
        password=$(aws ecr get-login-password --region "$REGION")
        
        kubectl create secret docker-registry ecr-secret \
            --docker-server="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com" \
            --docker-username=AWS \
            --docker-password="$password" \
            -n "$NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log_success "ECR secret created"
    else
        log_success "ECR secret already exists"
    fi
}

# Build helm command
build_helm_command() {
    local cmd="helm $ACTION $RELEASE_NAME-$ENVIRONMENT $CHART_PATH"
    cmd="$cmd --namespace $NAMESPACE --create-namespace"
    cmd="$cmd -f $VALUES_FILE"
    cmd="$cmd --set imagePullSecrets[0].name=ecr-secret"
    
    if [[ -n "$ALB_HOST" ]]; then
        cmd="$cmd --set ingress.host=$ALB_HOST"
    fi
    
    if [[ -n "$IMAGE_TAG" ]]; then
        cmd="$cmd --set backend.image.tag=$IMAGE_TAG"
        cmd="$cmd --set frontend.image.tag=$IMAGE_TAG"
    fi
    
    if [[ -n "$REPLICAS" ]]; then
        cmd="$cmd --set backend.replicas=$REPLICAS"
    fi
    
    if [[ -n "$DRY_RUN" ]]; then
        cmd="$cmd $DRY_RUN"
    fi
    
    echo "$cmd"
}

# Execute action
execute_action() {
    case "$ACTION" in
        install)
            ensure_ecr_secret
            log_info "Installing Helm release..."
            eval "$(build_helm_command)"
            log_success "Release installed successfully"
            ;;
        upgrade)
            log_info "Upgrading Helm release..."
            eval "$(build_helm_command)"
            log_success "Release upgraded successfully"
            ;;
        uninstall)
            log_info "Uninstalling Helm release..."
            helm uninstall "$RELEASE_NAME-$ENVIRONMENT" -n "$NAMESPACE" || true
            log_success "Release uninstalled"
            ;;
        status)
            log_info "Checking release status..."
            helm status "$RELEASE_NAME-$ENVIRONMENT" -n "$NAMESPACE"
            ;;
        values)
            log_info "Computed values for $ENVIRONMENT:"
            helm get values "$RELEASE_NAME-$ENVIRONMENT" -n "$NAMESPACE"
            ;;
        *)
            log_error "Invalid action: $ACTION"
            usage
            ;;
    esac
}

# Main
log_info "=========================================="
log_info "Three-Tier EKS Helm Deployment"
log_info "=========================================="
log_info "Environment: $ENVIRONMENT"
log_info "Namespace:   $NAMESPACE"
log_info "Action:      $ACTION"
log_info "Chart:       $CHART_PATH"
log_info "=========================================="

execute_action
