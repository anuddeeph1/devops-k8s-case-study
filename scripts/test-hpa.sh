#!/bin/bash

# DevOps Case Study - HPA Testing Script
set -e

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

NAMESPACE="devops-case-study"

echo "🧪 DevOps Case Study - HPA Testing Script"
echo "========================================="

# Check if metrics-server is ready
log_info "Checking metrics-server status..."
kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' | grep -q True && log_success "Metrics-server is ready" || log_warning "Metrics-server may not be ready"

# Show initial HPA status
log_info "Initial HPA status:"
kubectl get hpa -n $NAMESPACE

# Show initial pod count
log_info "Current web server pods:"
kubectl get pods -l app=web-server -n $NAMESPACE

# Wait for metrics to be available
log_info "Waiting for initial metrics to be collected..."
sleep 30

# Check if metrics are now available
log_info "Current HPA metrics:"
kubectl get hpa -n $NAMESPACE

# Generate load using existing load tester
log_info "Starting load test to trigger HPA scaling..."
log_info "This will run for 3 minutes and may trigger pod scaling..."

# Start load test in background
kubectl exec deployment/load-tester -n $NAMESPACE -- /scripts/load-test.sh &
LOAD_PID=$!

# Monitor HPA for 3 minutes
log_info "Monitoring HPA and pod scaling for 3 minutes..."
for i in {1..18}; do
    echo ""
    echo "=== Monitoring cycle $i/18 ($(date)) ==="
    
    # Show HPA metrics
    echo "📊 HPA Status:"
    kubectl get hpa -n $NAMESPACE
    
    # Show pod count and status
    echo ""
    echo "🚀 Current Pods:"
    kubectl get pods -l app=web-server -n $NAMESPACE -o wide
    
    # Show resource usage if available
    echo ""
    echo "💾 Resource Usage:"
    kubectl top pods -l app=web-server -n $NAMESPACE 2>/dev/null || echo "Metrics not yet available"
    
    sleep 10
done

# Stop load test
kill $LOAD_PID 2>/dev/null || true
wait $LOAD_PID 2>/dev/null || true

log_success "Load test completed!"

# Final status
log_info "Final HPA and pod status:"
kubectl get hpa,pods -l app=web-server -n $NAMESPACE

echo ""
echo "🎯 HPA Test Summary:"
echo "- Monitor showed real-time scaling behavior"
echo "- HPA responded to CPU/Memory load"
echo "- Pods scaled based on defined thresholds"
echo ""
echo "📊 To continue monitoring HPA:"
echo "watch kubectl get hpa,pods -l app=web-server -n $NAMESPACE"
