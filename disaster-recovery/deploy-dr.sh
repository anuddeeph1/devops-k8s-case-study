#!/bin/bash

# MySQL Disaster Recovery Deployment Script
set -e

echo "🚨 Deploying MySQL Disaster Recovery Solution"
echo "=============================================="

NAMESPACE="devops-case-study"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    log_error "Namespace $NAMESPACE does not exist. Please create it first."
    exit 1
fi

# Deploy disaster recovery components
log_info "Deploying backup storage..."
kubectl apply -f backup-storage.yaml

log_info "Waiting for PVC to be bound..."
kubectl wait --for=condition=Bound pvc/mysql-backup-pvc -n $NAMESPACE --timeout=60s

log_info "Deploying backup scripts..."
kubectl apply -f backup-script-configmap.yaml

log_info "Deploying backup CronJob..."
kubectl apply -f mysql-backup-cronjob.yaml

log_success "Disaster recovery components deployed successfully!"

echo ""
echo "📊 Deployment Status:"
kubectl get pvc,configmap,cronjob -n $NAMESPACE | grep -E "backup|mysql-backup"

echo ""
echo "🧪 Quick Test Commands:"
echo "# Create manual backup:"
echo "kubectl create job --from=cronjob/mysql-backup-cronjob manual-backup-\$(date +%s) -n $NAMESPACE"
echo ""
echo "# Check backup logs:"
echo "kubectl logs -l app=mysql-backup-job -n $NAMESPACE --tail=20"
echo ""
echo "# Deploy restore job (when needed):"
echo "kubectl apply -f mysql-restore-job.yaml"
echo ""
echo "# Verify database health:"
echo "kubectl apply -f mysql-verify-job.yaml"

echo ""
log_success "Disaster Recovery setup complete! 🎉"
echo "📖 See README.md for detailed usage instructions."
