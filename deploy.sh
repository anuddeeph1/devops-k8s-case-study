#!/bin/bash

# DevOps Case Study - Complete Deployment Script
set -e

echo "🚀 DevOps Case Study Deployment Script"
echo "======================================"

# Configuration
NAMESPACE="devops-case-study"
REGISTRY="anuddeeph"  # Docker Hub username
PROJECT_ROOT="$(pwd)"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    commands=("kind" "kubectl" "helm" "docker" "go")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is not installed. Please install it first."
            exit 1
        fi
    done
    
    log_success "All prerequisites are installed"
}

# Setup cluster
setup_cluster() {
    log_info "Setting up KIND cluster..."
    
    # Make setup script executable and run it
    chmod +x setup-cluster.sh
    ./setup-cluster.sh
    
    # Wait for cluster to be ready
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "KIND cluster is ready"
}

# Install ArgoCD for GitOps
setup_argocd() {
    log_info "Installing ArgoCD for GitOps deployment..."
    
    # Create ArgoCD namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get ArgoCD admin password
    log_info "Getting ArgoCD admin password..."
    sleep 10  # Wait for secret to be created
    ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Password not ready yet")
    
    # Setup port forwarding for ArgoCD (in background)
    kubectl port-forward svc/argocd-server -n argocd 8081:443 > /dev/null 2>&1 &
    ARGO_PF_PID=$!
    echo "$ARGO_PF_PID" > .argo-pf.pid
    
    log_success "ArgoCD installed and configured"
    log_info "ArgoCD admin password: $ARGO_PASSWORD"
    log_info "ArgoCD UI: https://localhost:8081 (admin/$ARGO_PASSWORD)"
}

# Build monitoring application
build_monitoring_app() {
    log_info "Building pod monitoring application..."
    
    cd monitoring
    
    # Build the Go application
    docker build -t ${REGISTRY}/pod-monitor:latest .
    
    # Push to Docker Hub (make sure you're logged in)
    echo "Pushing to Docker Hub..."
    docker push ${REGISTRY}/pod-monitor:latest
    
    cd "$PROJECT_ROOT"
    
    log_success "Pod monitoring application built and pushed"
}

# Deploy applications via ArgoCD
deploy_with_argocd() {
    log_info "Deploying applications via ArgoCD GitOps using App-of-Apps pattern..."
    
    # Deploy the App-of-Apps which will manage all applications
    log_info "Deploying App-of-Apps pattern..."
    kubectl apply -f argocd-apps/app-of-apps.yaml
    
    # Wait for app-of-apps to sync
    log_info "Waiting for App-of-Apps to sync..."
    for i in {1..10}; do
        STATUS=$(kubectl get application devops-case-study-apps -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        SYNC_STATUS=$(kubectl get application devops-case-study-apps -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        
        log_info "App-of-Apps - Health: $STATUS, Sync: $SYNC_STATUS"
        
        if [ "$STATUS" = "Healthy" ] && [ "$SYNC_STATUS" = "Synced" ]; then
            log_success "App-of-Apps deployed successfully!"
            break
        fi
        
        if [ "$i" -eq 10 ]; then
            log_warning "App-of-Apps deployment timed out. Continuing with individual app monitoring..."
        fi
        
        sleep 5
    done
    
    # Install ArgoCD CLI if not present (for local testing)
    if ! command -v argocd &> /dev/null; then
        log_warning "ArgoCD CLI not found. Install it for better GitOps management:"
        log_info "curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    fi
    
    # Wait for all applications to be healthy (with sync waves)
    APPS=("reports-server" "kyverno" "kyverno-policies" "kyverno-custom-policies" "devops-database" "devops-web-server" "devops-monitoring" "load-testing")
    log_info "Monitoring ArgoCD applications status (respecting sync waves)..."
    
    for app in "${APPS[@]}"; do
        log_info "Checking $app application..."
        for i in {1..30}; do  # Increased timeout for Kyverno components
            STATUS=$(kubectl get application $app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            SYNC_STATUS=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            
            log_info "$app - Health: $STATUS, Sync: $SYNC_STATUS"
            
            if [ "$STATUS" = "Healthy" ] && [ "$SYNC_STATUS" = "Synced" ]; then
                log_success "$app application deployed successfully!"
                break
            fi
            
            if [ "$i" -eq 30 ]; then
                log_warning "$app application deployment timed out. Check ArgoCD UI for details."
            fi
            
            sleep 10  # Longer wait for complex deployments like Kyverno
        done
    done
    
    # Verify Reports Server is working
    log_info "Verifying Reports Server deployment..."
    sleep 20  # Give Reports Server time to initialize
    
    # Check Reports Server pods
    REPORTS_PODS=$(kubectl get pods -n kyverno -l app.kubernetes.io/name=policy-reporter --no-headers 2>/dev/null | grep -v Completed | wc -l || echo "0")
    if [ "$REPORTS_PODS" -gt 0 ]; then
        log_success "Reports Server pods are running ($REPORTS_PODS pods)"
        
        # Check if API service is available
        API_SERVICE=$(kubectl get apiservice v1.reports.kyverno.io --no-headers 2>/dev/null | grep Available || echo "")
        if [ -n "$API_SERVICE" ]; then
            log_success "Reports Server API service is available"
        else
            log_warning "Reports Server API service not available yet. May need more time to initialize."
        fi
        
        # Check if PolicyReports are being generated
        sleep 10  # Give time for reports to be generated
        POLICY_REPORTS=$(kubectl get policyreports -A --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$POLICY_REPORTS" -gt 0 ]; then
            log_success "Policy reports are being generated ($POLICY_REPORTS reports)"
        else
            log_warning "No policy reports found yet. Reports may generate after policies are applied."
        fi
        
        # Check if ClusterPolicyReports exist
        CLUSTER_REPORTS=$(kubectl get clusterpolicyreports --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$CLUSTER_REPORTS" -gt 0 ]; then
            log_success "Cluster policy reports are available ($CLUSTER_REPORTS reports)"
        else
            log_warning "No cluster policy reports found yet."
        fi
        
        # Check Reports Server service
        REPORTS_SVC=$(kubectl get service -n kyverno -l app.kubernetes.io/name=policy-reporter --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$REPORTS_SVC" -gt 0 ]; then
            log_success "Reports Server service is available"
        else
            log_warning "Reports Server service not found."
        fi
    else
        log_warning "No Reports Server pods found. Check deployment status."
    fi
    
    # Verify Kyverno is working
    log_info "Verifying Kyverno deployment..."
    sleep 30  # Give Kyverno time to initialize
    
    # Check Kyverno pods
    KYVERNO_PODS=$(kubectl get pods -n kyverno --no-headers 2>/dev/null | grep -E "(kyverno|admission|background|cleanup|reports)" | grep -v Completed | wc -l || echo "0")
    if [ "$KYVERNO_PODS" -gt 0 ]; then
        log_success "Kyverno pods are running ($KYVERNO_PODS pods)"
        
        # Check if policies are loaded
        POLICIES=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$POLICIES" -gt 0 ]; then
            log_success "Kyverno policies are loaded ($POLICIES policies)"
        else
            log_warning "No Kyverno policies found. This may be expected if using audit mode."
        fi
        
        # Check if NetworkPolicies are generated
        NETPOLS=$(kubectl get networkpolicies -n devops-case-study --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$NETPOLS" -gt 0 ]; then
            log_success "NetworkPolicies generated by Kyverno ($NETPOLS policies)"
        else
            log_warning "No NetworkPolicies generated yet. Check Kyverno logs if expected."
        fi
        
        # Show detailed Kyverno status
        log_info "Kyverno component status:"
        kubectl get pods -n kyverno -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready" --no-headers 2>/dev/null | while read name status ready; do
            if [[ "$name" == *"kyverno"* ]]; then
                log_info "  $name: $status (Ready: $ready)"
            fi
        done
    else
        log_warning "No Kyverno pods found. Check deployment status."
    fi
    
    log_success "GitOps deployment completed - All applications deployed with Policy-as-Code!"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespace created/updated"
}

# Deploy components
deploy_components() {
    log_info "Deploying all components..."
    
    # Deploy database
    log_info "Deploying MySQL database..."
    kubectl apply -f database/ -n $NAMESPACE
    
    # Wait for database to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/mysql -n $NAMESPACE
    
    # Deploy web server
    log_info "Deploying web server..."
    kubectl apply -f web-server/ -n $NAMESPACE
    
    # Wait for web server to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/web-server -n $NAMESPACE
    
    # Deploy monitoring
    log_info "Deploying pod monitor..."
    kubectl apply -f monitoring/pod-monitor-deployment.yaml -n $NAMESPACE
    
    # Deploy load testing
    log_info "Deploying load testing components..."
    kubectl apply -f load-testing/ -n $NAMESPACE
    
    log_success "All components deployed successfully"
}

# Setup port forwarding
setup_port_forwarding() {
    log_info "Setting up port forwarding..."
    
    # Web server port forwarding
    kubectl port-forward -n $NAMESPACE service/web-server-service 8080:80 &
    WEB_PF_PID=$!
    
    # MySQL port forwarding (for external access)
    kubectl port-forward -n $NAMESPACE service/mysql-service 3306:3306 &
    DB_PF_PID=$!
    
    echo "$WEB_PF_PID" > .web-pf.pid
    echo "$DB_PF_PID" > .db-pf.pid
    
    log_success "Port forwarding setup complete"
    log_info "Web application: http://localhost:8080"
    log_info "MySQL database: localhost:3306"
}

# Test deployment
test_deployment() {
    log_info "Testing deployment..."
    
    # Test web server health
    sleep 5
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        log_success "Web server health check passed"
    else
        log_warning "Web server health check failed - may need more time to start"
    fi
    
    # Test database connectivity
    if kubectl exec -n $NAMESPACE deployment/mysql -- mysql -u root -proot123 -e "SELECT 1" > /dev/null 2>&1; then
        log_success "Database connectivity test passed"
    else
        log_warning "Database connectivity test failed"
    fi
    
    # Check HPA
    kubectl get hpa -n $NAMESPACE
    
    log_success "Deployment tests completed"
}

# Display status
show_status() {
    echo ""
    echo "======================================"
    log_success "Deployment Complete!"
    echo "======================================"
    echo ""
    
    echo "📊 Cluster Status:"
    kubectl get nodes
    echo ""
    
    echo "🏗️  Deployments in $NAMESPACE:"
    kubectl get deployments -n $NAMESPACE
    echo ""
    
    echo "🚀 Pods in $NAMESPACE:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    
    echo "🌐 Services in $NAMESPACE:"
    kubectl get services -n $NAMESPACE
    echo ""
    
    echo "📈 HPA Status:"
    kubectl get hpa -n $NAMESPACE
    echo ""
    
    echo "🔗 Access Information:"
    echo "  Web Application: http://localhost:8080"
    echo "  Database: localhost:3306 (root/root123)"
    echo ""
    
    echo "🧪 Testing Commands:"
    echo "  # Run load test"
    echo "  kubectl create job --from=cronjob/load-test-job load-test-manual -n $NAMESPACE"
    echo ""
    echo "  # Monitor HPA"
    echo "  watch kubectl get hpa,pods -n $NAMESPACE"
    echo ""
    echo "  # Check pod monitor logs"
    echo "  kubectl logs -f deployment/pod-monitor -n $NAMESPACE"
    echo ""
    
    echo "🛑 Cleanup Commands:"
    echo "  # Stop port forwarding"
    echo "  kill \$(cat .web-pf.pid .db-pf.pid 2>/dev/null) 2>/dev/null || true"
    echo ""
    echo "  # Delete cluster"
    echo "  kind delete cluster --name devops-case-study"
    echo ""
}

# Main deployment flow
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            setup_cluster
            sleep 10  # Give cluster time to stabilize
            build_monitoring_app
            create_namespace
            deploy_components
            setup_port_forwarding
            test_deployment
            show_status
            ;;
        "gitops")
            check_prerequisites
            setup_cluster
            sleep 10  # Give cluster time to stabilize
            setup_argocd
            build_monitoring_app
            create_namespace  # Create namespace before ArgoCD deployment
            deploy_with_argocd
            setup_port_forwarding
            sleep 30  # Give ArgoCD time to deploy
            test_deployment
            show_status
            ;;
        "cleanup")
            log_info "Cleaning up deployment..."
            
            # Stop port forwarding
            if [ -f .web-pf.pid ]; then
                kill $(cat .web-pf.pid) 2>/dev/null || true
                rm -f .web-pf.pid
            fi
            
            if [ -f .db-pf.pid ]; then
                kill $(cat .db-pf.pid) 2>/dev/null || true
                rm -f .db-pf.pid
            fi
            
            if [ -f .argo-pf.pid ]; then
                kill $(cat .argo-pf.pid) 2>/dev/null || true
                rm -f .argo-pf.pid
            fi
            
            # Delete KIND cluster
            kind delete cluster --name devops-case-study
            
            log_success "Cleanup completed"
            ;;
        "test")
            log_info "Running load test..."
            kubectl create job --from=cronjob/load-test-job load-test-manual-$(date +%s) -n $NAMESPACE
            log_success "Load test job created"
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 [deploy|gitops|cleanup|test|status]"
            echo ""
            echo "  deploy  - Full deployment using kubectl (default)"
            echo "  gitops  - GitOps deployment using ArgoCD"
            echo "  cleanup - Clean up everything"
            echo "  test    - Run load test"
            echo "  status  - Show current status"
            echo ""
            echo "GitOps deployment requires:"
            echo "  - Git repository with Helm charts"
            echo "  - ArgoCD access to the repository"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
