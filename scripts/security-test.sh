#!/bin/bash

# Security Tools Test Script
# This script tests the security scanning functionality with demo images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_SCAN_SCRIPT="$SCRIPT_DIR/security-scan.sh"
TEST_OUTPUT_DIR="./security-test-results"

# Test images - including some with known vulnerabilities for testing
TEST_IMAGES=(
    "alpine:latest"                    # Minimal image, should have few/no vulnerabilities
    "nginx:1.20"                       # Older nginx version, may have vulnerabilities
    "anuddeeph/pod-monitor:latest"     # Our custom image
)

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
    
    # Check if security-scan.sh exists
    if [ ! -f "$SECURITY_SCAN_SCRIPT" ]; then
        log_error "Security scan script not found at $SECURITY_SCAN_SCRIPT"
        exit 1
    fi
    
    # Check if script is executable
    if [ ! -x "$SECURITY_SCAN_SCRIPT" ]; then
        log_warning "Making security scan script executable..."
        chmod +x "$SECURITY_SCAN_SCRIPT"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

run_test_scan() {
    local image="$1"
    local output_subdir="$2"
    
    log_info "Testing security scan for image: $image"
    
    # Create output directory for this test
    local full_output_dir="$TEST_OUTPUT_DIR/$output_subdir"
    mkdir -p "$full_output_dir"
    
    # Run the security scan
    if "$SECURITY_SCAN_SCRIPT" "$image" "$full_output_dir"; then
        log_success "Security scan completed for $image"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            log_warning "Security scan completed with high-severity vulnerabilities for $image"
        elif [ $exit_code -eq 2 ]; then
            log_warning "Security scan completed with critical vulnerabilities for $image"
        else
            log_error "Security scan failed for $image"
            return 1
        fi
    fi
}

generate_test_summary() {
    log_info "Generating test summary..."
    
    cat > "$TEST_OUTPUT_DIR/test-summary.md" << EOF
# 🧪 Security Scanner Test Results

**Test Date:** $(date)  
**Test Directory:** $TEST_OUTPUT_DIR  
**Scanner Script:** $SECURITY_SCAN_SCRIPT  

## 📊 Test Results

| Image | Status | Vulnerabilities | SBOM Components | VEX Statements |
|-------|--------|-----------------|-----------------|----------------|
EOF

    # Add results for each test image
    for i in "${!TEST_IMAGES[@]}"; do
        local image="${TEST_IMAGES[$i]}"
        local output_subdir="test-$((i+1))-$(echo "$image" | tr '/:' '_-')"
        local full_output_dir="$TEST_OUTPUT_DIR/$output_subdir"
        
        if [ -f "$full_output_dir/grype/vulnerabilities.json" ]; then
            local vuln_count="0"
            local sbom_count="0"
            local vex_count="0"
            
            if command -v jq &> /dev/null; then
                vuln_count=$(jq '.matches | length' "$full_output_dir/grype/vulnerabilities.json" 2>/dev/null || echo "0")
                if [ -f "$full_output_dir/sbom/sbom.cyclonedx.json" ]; then
                    sbom_count=$(jq '.components | length' "$full_output_dir/sbom/sbom.cyclonedx.json" 2>/dev/null || echo "0")
                fi
                if [ -f "$full_output_dir/vex/vex-document.json" ]; then
                    vex_count=$(jq '.statements | length' "$full_output_dir/vex/vex-document.json" 2>/dev/null || echo "0")
                fi
            fi
            
            echo "| \`$image\` | ✅ Success | $vuln_count | $sbom_count | $vex_count |" >> "$TEST_OUTPUT_DIR/test-summary.md"
        else
            echo "| \`$image\` | ❌ Failed | - | - | - |" >> "$TEST_OUTPUT_DIR/test-summary.md"
        fi
    done

    cat >> "$TEST_OUTPUT_DIR/test-summary.md" << EOF

## 📁 Test Output Structure

\`\`\`
$TEST_OUTPUT_DIR/
├── test-summary.md                    # This summary report
EOF

    # Add directory structure for each test
    for i in "${!TEST_IMAGES[@]}"; do
        local image="${TEST_IMAGES[$i]}"
        local output_subdir="test-$((i+1))-$(echo "$image" | tr '/:' '_-')"
        
        cat >> "$TEST_OUTPUT_DIR/test-summary.md" << EOF
├── $output_subdir/                    # Results for $image
│   ├── grype/
│   │   ├── vulnerabilities.json      # Detailed vulnerability data
│   │   ├── vulnerabilities.txt       # Human-readable report
│   │   └── vulnerabilities.sarif     # SARIF format
│   ├── sbom/
│   │   ├── sbom.cyclonedx.json       # CycloneDX SBOM
│   │   ├── sbom.spdx.json            # SPDX SBOM
│   │   └── sbom.txt                  # Human-readable SBOM
│   ├── vex/
│   │   └── vex-document.json         # VEX document
│   └── security-summary.md           # Individual image summary
EOF
    done

    cat >> "$TEST_OUTPUT_DIR/test-summary.md" << EOF
\`\`\`

## 🔧 Usage Examples

### Individual Image Testing
\`\`\`bash
# Test specific image
$SECURITY_SCAN_SCRIPT nginx:latest ./my-security-reports

# Test with custom output directory
$SECURITY_SCAN_SCRIPT anuddeeph/pod-monitor:latest ./pod-monitor-security
\`\`\`

### Automated Testing
\`\`\`bash
# Run full test suite
$SCRIPT_DIR/security-test.sh

# Clean up test results
rm -rf $TEST_OUTPUT_DIR
\`\`\`

## 🎯 Next Steps

1. **Review Individual Reports**: Check each test directory for detailed results
2. **Validate Tools**: Ensure Grype, Syft, and Cosign are working correctly
3. **CI/CD Integration**: Use this as a reference for pipeline integration
4. **Custom Testing**: Add your own images to the test suite

---

**Generated by Security Test Suite** 🛡️
EOF

    log_success "Test summary generated at $TEST_OUTPUT_DIR/test-summary.md"
}

cleanup_old_results() {
    if [ -d "$TEST_OUTPUT_DIR" ]; then
        log_warning "Removing old test results..."
        rm -rf "$TEST_OUTPUT_DIR"
    fi
}

main() {
    echo "🧪 Security Scanner Test Suite"
    echo "==============================="
    echo ""
    
    # Parse command line arguments
    CLEANUP_ONLY=false
    KEEP_RESULTS=false
    
    for arg in "$@"; do
        case $arg in
            --cleanup|-c)
                CLEANUP_ONLY=true
                shift
                ;;
            --keep-results|-k)
                KEEP_RESULTS=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --cleanup, -c      Only cleanup old results and exit"
                echo "  --keep-results, -k Keep old results and append new ones"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "Test Images:"
                for image in "${TEST_IMAGES[@]}"; do
                    echo "  - $image"
                done
                exit 0
                ;;
        esac
    done
    
    if [ "$CLEANUP_ONLY" = true ]; then
        log_info "Cleanup mode: removing test results..."
        cleanup_old_results
        log_success "Cleanup completed"
        exit 0
    fi
    
    # Setup
    check_prerequisites
    
    if [ "$KEEP_RESULTS" != true ]; then
        cleanup_old_results
    fi
    
    mkdir -p "$TEST_OUTPUT_DIR"
    
    # Run tests for each image
    log_info "Starting security scanner tests..."
    echo ""
    
    local test_count=0
    local success_count=0
    
    for i in "${!TEST_IMAGES[@]}"; do
        local image="${TEST_IMAGES[$i]}"
        local output_subdir="test-$((i+1))-$(echo "$image" | tr '/:' '_-')"
        
        echo "----------------------------------------"
        log_info "Test $((i+1))/${#TEST_IMAGES[@]}: $image"
        echo "----------------------------------------"
        
        if run_test_scan "$image" "$output_subdir"; then
            ((success_count++))
        fi
        ((test_count++))
        echo ""
    done
    
    # Generate summary
    generate_test_summary
    
    # Display final results
    echo "=========================================="
    echo "🏁 TEST SUITE COMPLETED"
    echo "=========================================="
    echo "Total tests: $test_count"
    echo "Successful: $success_count"
    echo "Failed: $((test_count - success_count))"
    echo ""
    echo "📄 Summary report: $TEST_OUTPUT_DIR/test-summary.md"
    echo "📁 Test results: $TEST_OUTPUT_DIR/"
    echo ""
    
    if [ $success_count -eq $test_count ]; then
        log_success "All tests completed successfully!"
        exit 0
    else
        log_warning "Some tests had issues. Check individual reports for details."
        exit 1
    fi
}

# Run main function
main "$@"
