#!/bin/bash

# Security-Enhanced Docker Build Script for Pod Monitor
# This script builds the pod-monitor container with security scanning enabled

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${IMAGE_NAME:-anuddeeph/pod-monitor}"
IMAGE_TAG="${IMAGE_TAG:-security-$(date +%Y%m%d-%H%M%S)}"
ENABLE_SECURITY_SCAN="${ENABLE_SECURITY_SCAN:-true}"
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "Dockerfile" ] || [ ! -f "main.go" ]; then
        log_error "Please run this script from the monitoring-go-controller directory"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

build_image() {
    log_info "Building security-enhanced container image..."
    log_info "Image: $IMAGE_NAME:$IMAGE_TAG"
    log_info "Git Commit: $GIT_COMMIT"
    log_info "Security Scan: $ENABLE_SECURITY_SCAN"
    
    # Build the image with security scanning enabled
    docker build \
        --build-arg ENABLE_SECURITY_SCAN="$ENABLE_SECURITY_SCAN" \
        --build-arg GIT_COMMIT="$GIT_COMMIT" \
        --label "build.time=$(date -u +%Y%m%d%H%M%S)" \
        --label "build.git.commit=$GIT_COMMIT" \
        --label "security.scan.date=$(date -u +%Y-%m-%d)" \
        -t "$IMAGE_NAME:$IMAGE_TAG" \
        -t "$IMAGE_NAME:latest-security" \
        .
    
    if [ $? -eq 0 ]; then
        log_success "Container build completed successfully"
    else
        log_error "Container build failed"
        exit 1
    fi
}

run_post_build_security_scan() {
    if [ "$ENABLE_SECURITY_SCAN" = "true" ]; then
        log_info "Running post-build security scan..."
        
        # Create output directory
        mkdir -p security-reports
        
        # Check if security scan script exists
        SECURITY_SCRIPT="../scripts/security-scan.sh"
        if [ -f "$SECURITY_SCRIPT" ]; then
            log_info "Running comprehensive security scan..."
            if bash "$SECURITY_SCRIPT" "$IMAGE_NAME:$IMAGE_TAG" "./security-reports"; then
                log_success "Security scan completed successfully"
            else
                local exit_code=$?
                if [ $exit_code -eq 1 ]; then
                    log_warning "Security scan completed with high-severity vulnerabilities"
                elif [ $exit_code -eq 2 ]; then
                    log_warning "Security scan completed with critical vulnerabilities"
                else
                    log_error "Security scan failed"
                fi
            fi
        else
            log_warning "Security scan script not found at $SECURITY_SCRIPT"
            log_info "Running basic vulnerability scan with Grype..."
            
            # Try to run Grype directly if available
            if command -v grype &> /dev/null; then
                grype "$IMAGE_NAME:$IMAGE_TAG" -o table > security-reports/vulnerabilities.txt || true
                grype "$IMAGE_NAME:$IMAGE_TAG" -o json > security-reports/vulnerabilities.json || true
                log_info "Basic vulnerability scan completed"
            else
                log_warning "Grype not available, skipping post-build scan"
            fi
        fi
    else
        log_info "Security scanning disabled, skipping post-build scan"
    fi
}

display_build_summary() {
    log_info "Build summary:"
    echo "  Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "  Git Commit: $GIT_COMMIT"
    echo "  Security Scan: $ENABLE_SECURITY_SCAN"
    echo "  Build Date: $(date)"
    
    # Show image details
    if docker image inspect "$IMAGE_NAME:$IMAGE_TAG" &>/dev/null; then
        local image_size=$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format='{{.Size}}' | numfmt --to=iec --suffix=B)
        echo "  Image Size: $image_size"
        
        # Show security labels
        echo ""
        log_info "Security labels:"
        docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format='{{range $k, $v := .Config.Labels}}{{if or (contains $k "security") (contains $k "grype") (contains $k "syft") (contains $k "cosign")}}  {{$k}}: {{$v}}{{"\n"}}{{end}}{{end}}'
    fi
    
    # Show available tags
    echo ""
    log_info "Available tags:"
    docker images "$IMAGE_NAME" --format "  {{.Repository}}:{{.Tag}} ({{.CreatedSince}}, {{.Size}})"
}

push_image() {
    if [ "$PUSH_IMAGE" = "true" ]; then
        log_info "Pushing image to registry..."
        
        docker push "$IMAGE_NAME:$IMAGE_TAG"
        docker push "$IMAGE_NAME:latest-security"
        
        log_success "Image pushed successfully"
    else
        log_info "Skipping image push (set PUSH_IMAGE=true to enable)"
    fi
}

main() {
    echo "🐳 Security-Enhanced Container Build"
    echo "===================================="
    echo ""
    
    # Parse command line arguments
    for arg in "$@"; do
        case $arg in
            --push)
                export PUSH_IMAGE=true
                shift
                ;;
            --no-security-scan)
                export ENABLE_SECURITY_SCAN=false
                shift
                ;;
            --tag=*)
                export IMAGE_TAG="${arg#*=}"
                shift
                ;;
            --name=*)
                export IMAGE_NAME="${arg#*=}"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --push                 Push image to registry after build"
                echo "  --no-security-scan     Disable security scanning during build"
                echo "  --tag=TAG             Custom image tag (default: security-YYYYMMDD-HHMMSS)"
                echo "  --name=NAME           Custom image name (default: anuddeeph/pod-monitor)"
                echo "  --help, -h            Show this help message"
                echo ""
                echo "Environment variables:"
                echo "  IMAGE_NAME            Container image name"
                echo "  IMAGE_TAG             Container image tag" 
                echo "  ENABLE_SECURITY_SCAN  Enable/disable security scanning (true/false)"
                echo "  PUSH_IMAGE            Push image after build (true/false)"
                exit 0
                ;;
        esac
    done
    
    check_prerequisites
    build_image
    run_post_build_security_scan
    display_build_summary
    push_image
    
    echo ""
    log_success "Security-enhanced build completed!"
    echo "🔒 Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "📊 Security reports: ./security-reports/"
    
    if [ "$ENABLE_SECURITY_SCAN" = "true" ] && [ -f "security-reports/security-summary.md" ]; then
        echo "📄 Security summary: ./security-reports/security-summary.md"
    fi
}

# Run main function
main "$@"
