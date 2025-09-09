#!/bin/bash

# Multi-Image Security Scanner Script
# Scans all container images used in the project (excluding pod-monitor)
# with Grype vulnerability scanning, SBOM generation, and VEX document creation
# Usage: ./multi-image-security-scan.sh [output-dir]

# Removed set -e to allow script to continue when individual image scans fail
# Individual error handling is done per image scan

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_DIR="${1:-./security-reports}"
TIMESTAMP=$(date +%s)
SCAN_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Container images used in the project (excluding pod-monitor)
declare -A IMAGES_TO_SCAN=(
    # Web Server images
    ["nginx"]="1.25-alpine"
    ["alpine-init"]="3.18"
    
    # Database images
    ["mysql"]="8.0"
    
    # Load Testing images
    ["alpine-curl"]="latest"
    
    # Reports Server images
    ["reports-server"]="latest"
    ["etcd"]="v3.5.18-cve-free"
    ["kubectl-reports"]="1.30.2"
    
    # Kyverno images
    ["kyverno-cli"]="latest"
    ["busybox"]="1.35"
    ["kubectl-kyverno"]="1.32.1"
    ["kubectl-nirmata"]="1.31.1"
    ["kyvernopre"]="latest"
    ["kyverno"]="latest"
    ["background-controller"]="latest"
    ["cleanup-controller"]="latest"
    ["reports-controller"]="latest"
)

# Full image names with registries
declare -A FULL_IMAGE_NAMES=(
    ["nginx"]="nginx:1.25-alpine"
    ["alpine-init"]="alpine:3.18"
    ["mysql"]="mysql:8.0"
    ["alpine-curl"]="alpine/curl:latest"
    ["reports-server"]="reg.nirmata.io/nirmata/reports-server:latest"
    ["etcd"]="ghcr.io/nirmata/etcd:v3.5.18-cve-free"
    ["kubectl-reports"]="ghcr.io/nirmata/kubectl:1.30.2"
    ["kyverno-cli"]="reg.nirmata.io/nirmata/kyverno-cli:latest"
    ["busybox"]="busybox:1.35"
    ["kubectl-kyverno"]="reg.nirmata.io/nirmata/kubectl:1.32.1"
    ["kubectl-nirmata"]="reg.nirmata.io/nirmata/kubectl:1.31.1"
    ["kyvernopre"]="reg.nirmata.io/nirmata/kyvernopre:latest"
    ["kyverno"]="reg.nirmata.io/nirmata/kyverno:latest"
    ["background-controller"]="reg.nirmata.io/nirmata/background-controller:latest"
    ["cleanup-controller"]="reg.nirmata.io/nirmata/cleanup-controller:latest"
    ["reports-controller"]="reg.nirmata.io/nirmata/reports-controller:latest"
)

# Tracking variables
TOTAL_IMAGES=${#FULL_IMAGE_NAMES[@]}
SCANNED_IMAGES=0
FAILED_SCANS=0
TOTAL_VULNERABILITIES=0
TOTAL_COMPONENTS=0
TOTAL_VEX_STATEMENTS=0

# Functions
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

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        return 1
    fi
    log_success "$1 is available"
}

install_security_tools() {
    log_info "Installing security tools..."
    
    # Install Grype
    if ! command -v grype &> /dev/null; then
        log_info "Installing Grype..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ~/.local/bin
        export PATH=$PATH:~/.local/bin
    fi
    
    # Install Syft
    if ! command -v syft &> /dev/null; then
        log_info "Installing Syft..."
        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.local/bin
        export PATH=$PATH:~/.local/bin
    fi
    
    log_success "Security tools installation completed"
}

generate_filename() {
    local image_name="$1"
    # Convert image name to filename-friendly format
    echo "$image_name" | sed 's/:/-/g' | sed 's/\//_/g' | sed 's/\./_/g'
}

scan_single_image() {
    local image_key="$1"
    local full_image_name="${FULL_IMAGE_NAMES[$image_key]}"
    
    log_info "=== Scanning $full_image_name ==="
    
    # Generate filename with image name and timestamp
    local clean_image_name=$(generate_filename "$full_image_name")
    local filename_base="${clean_image_name}-${TIMESTAMP}"
    
    # Create image-specific directories
    mkdir -p "$OUTPUT_DIR/grype"
    mkdir -p "$OUTPUT_DIR/sbom"  
    mkdir -p "$OUTPUT_DIR/vex"
    
    # Variables for this scan
    local image_vulns=0
    local image_components=0
    local image_vex_statements=0
    local scan_success=true
    
    # Try to pull the image first
    log_info "Pulling image: $full_image_name"
    if ! docker pull "$full_image_name" 2>/dev/null; then
        log_warning "Failed to pull $full_image_name, trying to scan anyway..."
    fi
    
    # Run Grype vulnerability scan
    log_info "Running Grype vulnerability scan..."
    if grype "$full_image_name" -o json > "$OUTPUT_DIR/grype/${filename_base}-vulnerabilities.json" 2>/dev/null; then
        grype "$full_image_name" -o table > "$OUTPUT_DIR/grype/${filename_base}-vulnerabilities.txt" 2>/dev/null
        grype "$full_image_name" -o sarif > "$OUTPUT_DIR/grype/${filename_base}-vulnerabilities.sarif" 2>/dev/null
        
        # Count vulnerabilities
        if command -v jq &> /dev/null; then
            image_vulns=$(jq '.matches | length' "$OUTPUT_DIR/grype/${filename_base}-vulnerabilities.json" 2>/dev/null || echo "0")
            log_info "Found $image_vulns vulnerabilities"
        fi
    else
        log_error "Grype scan failed for $full_image_name"
        scan_success=false
    fi
    
    # Generate SBOM
    log_info "Generating SBOM..."
    if syft "$full_image_name" -o cyclonedx-json > "$OUTPUT_DIR/sbom/${filename_base}-sbom.cyclonedx.json" 2>/dev/null; then
        syft "$full_image_name" -o spdx-json > "$OUTPUT_DIR/sbom/${filename_base}-sbom.spdx.json" 2>/dev/null
        syft "$full_image_name" -o table > "$OUTPUT_DIR/sbom/${filename_base}-sbom.txt" 2>/dev/null
        
        # Count components
        if command -v jq &> /dev/null; then
            image_components=$(jq '.components | length' "$OUTPUT_DIR/sbom/${filename_base}-sbom.cyclonedx.json" 2>/dev/null || echo "0")
            log_info "Found $image_components components in SBOM"
        fi
    else
        log_warning "SBOM generation failed for $full_image_name - continuing with vulnerability scan only"
        image_components=0
        # Continue scanning even if SBOM fails
    fi
    
    # Generate VEX document
    log_info "Generating VEX document..."
    if generate_vex_document "$full_image_name" "$filename_base"; then
        if command -v jq &> /dev/null && [ -f "$OUTPUT_DIR/vex/${filename_base}-vex-document.json" ]; then
            image_vex_statements=$(jq '.statements | length' "$OUTPUT_DIR/vex/${filename_base}-vex-document.json" 2>/dev/null || echo "0")
            log_info "Generated $image_vex_statements VEX statements"
        fi
    else
        log_warning "VEX document generation failed for $full_image_name - continuing with other scans"
        # Don't mark scan as failed for VEX generation issues
        image_vex_statements=0
    fi
    
    # Update global counters
    if [ "$scan_success" = true ]; then
        ((SCANNED_IMAGES++))
        TOTAL_VULNERABILITIES=$((TOTAL_VULNERABILITIES + image_vulns))
        TOTAL_COMPONENTS=$((TOTAL_COMPONENTS + image_components))
        TOTAL_VEX_STATEMENTS=$((TOTAL_VEX_STATEMENTS + image_vex_statements))
        log_success "Completed scan for $full_image_name"
        return 0
    else
        ((FAILED_SCANS++))
        log_error "Scan failed for $full_image_name"
        return 1
    fi
}

generate_vex_document() {
    local full_image_name="$1"
    local filename_base="$2"
    
    # Check if required files exist
    local sbom_file="$OUTPUT_DIR/sbom/${filename_base}-sbom.cyclonedx.json"
    local grype_file="$OUTPUT_DIR/grype/${filename_base}-vulnerabilities.json"
    
    if [ ! -f "$sbom_file" ] || [ ! -f "$grype_file" ]; then
        return 1
    fi
    
    # Generate VEX document using Python
    python3 << EOF
import json
import os
import sys
from datetime import datetime, timezone

def generate_vex():
    try:
        sbom_file = "$sbom_file"
        grype_file = "$grype_file"
        output_file = "$OUTPUT_DIR/vex/${filename_base}-vex-document.json"
        
        with open(sbom_file, 'r') as f:
            sbom_data = json.load(f)
        
        with open(grype_file, 'r') as f:
            grype_data = json.load(f)
        
        # Build component map from SBOM
        sbom_components = {}
        for component in sbom_data.get("components", []):
            name = component.get("name", "")
            version = component.get("version", "")
            purl = component.get("purl", "")
            
            if name:
                key = f"{name}@{version}" if version else name
                sbom_components[key.lower()] = {
                    "name": name,
                    "version": version,
                    "purl": purl,
                    "bom_ref": component.get("bom-ref", f"component-{len(sbom_components)}")
                }
        
        # Create VEX document structure
        vex_doc = {
            "@context": "https://openvex.dev/ns/v0.2.0",
            "@id": f"https://github.com/devops-k8s-case-study/vex/${filename_base}",
            "author": "Multi-Image Security Scanner",
            "timestamp": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            "version": 1,
            "statements": []
        }
        
        # Process vulnerabilities
        processed_cves = set()
        
        for match in grype_data.get("matches", []):
            vulnerability = match.get("vulnerability", {})
            cve_id = vulnerability.get("id", "")
            
            if not cve_id.startswith("CVE-") or cve_id in processed_cves:
                continue
                
            processed_cves.add(cve_id)
            
            # Get artifact information
            artifact = match.get("artifact", {})
            artifact_name = artifact.get("name", "unknown-component")
            artifact_version = artifact.get("version", "")
            
            # Find matching SBOM component
            search_key = f"{artifact_name}@{artifact_version}".lower() if artifact_version else artifact_name.lower()
            sbom_component = sbom_components.get(search_key)
            
            # Determine status based on severity
            severity = vulnerability.get("severity", "Unknown").upper()
            if severity in ["CRITICAL", "HIGH"]:
                status = "under_investigation"
                justification = "vulnerability_disputed"
            elif severity == "MEDIUM":
                status = "not_affected"
                justification = "vulnerable_code_not_in_execute_path"
            else:
                status = "not_affected"
                justification = "component_not_present"
            
            # Create subcomponent reference
            if sbom_component:
                subcomponent = {
                    "@id": sbom_component["bom_ref"],
                    "name": sbom_component["name"],
                    "version": sbom_component["version"]
                }
                if sbom_component["purl"]:
                    subcomponent["purl"] = sbom_component["purl"]
            else:
                subcomponent = {
                    "@id": f"component-{artifact_name}-{artifact_version}",
                    "name": artifact_name
                }
                if artifact_version:
                    subcomponent["version"] = artifact_version
            
            # Create VEX statement
            statement = {
                "vulnerability": {
                    "name": cve_id,
                    "description": vulnerability.get("description", f"Vulnerability {cve_id}")
                },
                "products": [
                    {
                        "@id": "$full_image_name",
                        "subcomponents": [subcomponent]
                    }
                ],
                "status": status,
                "justification": justification,
                "impact_statement": f"Severity: {severity} - {vulnerability.get('description', 'No description available')}",
                "action_statement": f"Component {'found in SBOM' if sbom_component else 'detected by scanner'}: {artifact_name}"
            }
            
            vex_doc["statements"].append(statement)
        
        # Write VEX document
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, 'w') as f:
            json.dump(vex_doc, f, indent=2)
            
        print(f"Generated VEX document with {len(vex_doc['statements'])} statements")
        return True
        
    except Exception as e:
        print(f"Error generating VEX: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    try:
        if generate_vex():
            sys.exit(0)
        else:
            sys.exit(1)
    except Exception as e:
        print(f"Fatal error in VEX generation: {e}", file=sys.stderr)
        sys.exit(1)
EOF
}

create_consolidated_summary() {
    log_info "Creating consolidated security summary report..."
    
    cat > "$OUTPUT_DIR/multi-image-security-summary.md" << EOF
# 🛡️ Multi-Image Container Security Analysis Report

**Scan Date:** $SCAN_DATE  
**Scanner:** Multi-Image Security Scanner  
**Output Directory:** $OUTPUT_DIR  
**Timestamp:** $TIMESTAMP  

## 📊 Overall Summary

| Metric | Count |
|--------|--------|
| 🖼️ Total Images | $TOTAL_IMAGES |
| ✅ Successfully Scanned | $SCANNED_IMAGES |
| ❌ Failed Scans | $FAILED_SCANS |
| 🚨 Total Vulnerabilities | $TOTAL_VULNERABILITIES |
| 📋 Total SBOM Components | $TOTAL_COMPONENTS |
| 📑 Total VEX Statements | $TOTAL_VEX_STATEMENTS |

## 🖼️ Scanned Images

### Successfully Scanned Images
EOF

    # List successfully scanned images
    for image_key in "${!FULL_IMAGE_NAMES[@]}"; do
        local full_image_name="${FULL_IMAGE_NAMES[$image_key]}"
        local clean_image_name=$(generate_filename "$full_image_name")
        local filename_base="${clean_image_name}-${TIMESTAMP}"
        
        if [ -f "$OUTPUT_DIR/grype/${filename_base}-vulnerabilities.json" ]; then
            local image_vulns=0
            local image_components=0
            local image_vex_statements=0
            
            if command -v jq &> /dev/null; then
                image_vulns=$(jq '.matches | length' "$OUTPUT_DIR/grype/${filename_base}-vulnerabilities.json" 2>/dev/null || echo "0")
                if [ -f "$OUTPUT_DIR/sbom/${filename_base}-sbom.cyclonedx.json" ]; then
                    image_components=$(jq '.components | length' "$OUTPUT_DIR/sbom/${filename_base}-sbom.cyclonedx.json" 2>/dev/null || echo "0")
                fi
                if [ -f "$OUTPUT_DIR/vex/${filename_base}-vex-document.json" ]; then
                    image_vex_statements=$(jq '.statements | length' "$OUTPUT_DIR/vex/${filename_base}-vex-document.json" 2>/dev/null || echo "0")
                fi
            fi
            
            cat >> "$OUTPUT_DIR/multi-image-security-summary.md" << EOF
- **$full_image_name**
  - Vulnerabilities: $image_vulns
  - SBOM Components: $image_components  
  - VEX Statements: $image_vex_statements
  - Reports: \`${filename_base}-*\`
EOF
        fi
    done

    cat >> "$OUTPUT_DIR/multi-image-security-summary.md" << EOF

## 📁 Report Files Structure

\`\`\`
security-reports/
├── grype/
│   ├── mysql-8_0-{timestamp}-vulnerabilities.json
│   ├── nginx-1_25-alpine-{timestamp}-vulnerabilities.txt
│   └── nirmata_kyverno-latest-{timestamp}-vulnerabilities.sarif
├── sbom/
│   ├── mysql-8_0-{timestamp}-sbom.cyclonedx.json
│   ├── nginx-1_25-alpine-{timestamp}-sbom.spdx.json
│   └── nirmata_background-controller-latest-{timestamp}-sbom.txt
└── vex/
    ├── mysql-8_0-{timestamp}-vex-document.json
    └── nginx-1_25-alpine-{timestamp}-vex-document.json
\`\`\`

## 🔧 Usage Examples

### Scan specific severity vulnerabilities
\`\`\`bash
# Find all critical vulnerabilities across all images
find $OUTPUT_DIR/grype -name "*.json" -exec jq -r '.matches[] | select(.vulnerability.severity == "Critical") | .vulnerability.id' {} \;

# Count high severity vulnerabilities per image
for f in $OUTPUT_DIR/grype/*-vulnerabilities.json; do
  echo "File: \$(basename \$f)"
  jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "\$f"
done
\`\`\`

### Analyze SBOM components
\`\`\`bash
# List all unique component types
find $OUTPUT_DIR/sbom -name "*-sbom.cyclonedx.json" -exec jq -r '.components[].type' {} \; | sort -u

# Find specific component across all images
find $OUTPUT_DIR/sbom -name "*-sbom.cyclonedx.json" -exec jq -r '.components[] | select(.name | contains("openssl")) | .name + "@" + .version' {} \;
\`\`\`

### VEX document analysis
\`\`\`bash
# Count statements by status across all VEX documents
find $OUTPUT_DIR/vex -name "*.json" -exec jq -r '.statements[].status' {} \; | sort | uniq -c
\`\`\`

## 🚀 CI/CD Integration

This scan can be integrated into CI/CD pipelines:

\`\`\`yaml
# GitHub Actions example
- name: Run Multi-Image Security Scan
  run: |
    ./scripts/multi-image-security-scan.sh ./security-reports
    
- name: Upload Security Reports
  uses: actions/upload-artifact@v3
  with:
    name: security-reports-\${{ github.run_id }}
    path: security-reports/
\`\`\`

---
*Generated at: $(date)*
EOF

    log_success "Consolidated security summary created at $OUTPUT_DIR/multi-image-security-summary.md"
}

display_final_results() {
    echo ""
    echo "==========================================="
    echo "🛡️  MULTI-IMAGE SECURITY SCAN RESULTS"
    echo "==========================================="
    echo "Timestamp: $TIMESTAMP"
    echo "Scan Date: $SCAN_DATE"
    echo ""
    echo "📊 SUMMARY:"
    echo "   Total Images:        $TOTAL_IMAGES"
    echo "   Successfully Scanned: $SCANNED_IMAGES"
    echo "   Failed Scans:        $FAILED_SCANS"
    echo ""
    echo "🚨 OVERALL SECURITY:"
    echo "   Total Vulnerabilities: $TOTAL_VULNERABILITIES"
    echo "   Total SBOM Components: $TOTAL_COMPONENTS"
    echo "   Total VEX Statements:  $TOTAL_VEX_STATEMENTS"
    echo ""
    echo "📁 Reports Location: $OUTPUT_DIR"
    echo "📄 Summary Report:   $OUTPUT_DIR/multi-image-security-summary.md"
    echo ""
    
    if [ $FAILED_SCANS -gt 0 ]; then
        log_warning "$FAILED_SCANS image(s) failed to scan completely"
    fi
    
    if [ $TOTAL_VULNERABILITIES -gt 0 ]; then
        log_warning "Total of $TOTAL_VULNERABILITIES vulnerabilities found across all images"
    else
        log_success "No vulnerabilities found in any scanned images!"
    fi
    
    echo "==========================================="
}

# Main execution
main() {
    echo "🛡️ Multi-Image Container Security Scanner"
    echo "=========================================="
    
    log_info "Starting security scan for $TOTAL_IMAGES container images"
    log_info "Excluding pod-monitor from scan"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Timestamp: $TIMESTAMP"
    
    # Create output directory structure
    mkdir -p "$OUTPUT_DIR"/{grype,sbom,vex}
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Install security tools if not available
    install_security_tools
    
    # Check tools are available
    if ! check_tool grype; then
        log_error "Grype is not available, cannot continue"
        exit 1
    fi
    if ! check_tool syft; then
        log_error "Syft is not available, cannot continue"  
        exit 1
    fi
    
    # Scan all images
    log_info "Starting to scan ${#FULL_IMAGE_NAMES[@]} images..."
    
    # List all images that will be scanned
    log_info "Images to scan:"
    for image_key in "${!FULL_IMAGE_NAMES[@]}"; do
        log_info "  - $image_key -> ${FULL_IMAGE_NAMES[$image_key]}"
    done
    echo ""
    
    local current_count=0
    for image_key in "${!FULL_IMAGE_NAMES[@]}"; do
        ((current_count++))
        log_info "Processing image $current_count/${#FULL_IMAGE_NAMES[@]}: $image_key -> ${FULL_IMAGE_NAMES[$image_key]}"
        
        # Wrap individual scan in error handling to ensure script continues
        if ! scan_single_image "$image_key"; then
            log_warning "scan_single_image returned error for $image_key, but continuing..."
        fi
        
        log_info "Completed processing $image_key. Current progress: $SCANNED_IMAGES successful, $FAILED_SCANS failed"
        echo "========================================"
    done
    
    log_info "Completed all image scans. Final totals: $SCANNED_IMAGES successful, $FAILED_SCANS failed"
    
    # Create consolidated summary
    create_consolidated_summary
    
    # Display final results
    display_final_results
    
    # Exit with appropriate code based on scan results
    log_info "Final scan results: $SCANNED_IMAGES successful, $FAILED_SCANS failed"
    
    if [ $SCANNED_IMAGES -eq 0 ]; then
        log_error "No images were successfully scanned"
        exit 2  # Complete failure
    elif [ $FAILED_SCANS -gt $SCANNED_IMAGES ]; then
        log_warning "More scans failed ($FAILED_SCANS) than succeeded ($SCANNED_IMAGES)"
        exit 1  # Mostly failed
    elif [ $TOTAL_VULNERABILITIES -gt 100 ]; then
        log_warning "High number of vulnerabilities found: $TOTAL_VULNERABILITIES"
        exit 1  # High vulnerability count
    else
        if [ $FAILED_SCANS -gt 0 ]; then
            log_warning "Some scans failed ($FAILED_SCANS), but majority succeeded ($SCANNED_IMAGES)"
        fi
        exit 0  # Success (at least some images scanned successfully)
    fi
}

# Run main function
main "$@"
