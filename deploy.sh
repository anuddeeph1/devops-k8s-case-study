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
            echo "Usage: $0 [deploy|cleanup|test|status]"
            echo ""
            echo "  deploy  - Full deployment (default)"
            echo "  cleanup - Clean up everything"
            echo "  test    - Run load test"
            echo "  status  - Show current status"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
