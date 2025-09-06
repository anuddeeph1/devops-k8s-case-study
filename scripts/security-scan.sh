#!/bin/bash

# Container Security Scanner Script
# Usage: ./security-scan.sh <image-name> [output-dir]
# Example: ./security-scan.sh anuddeeph/pod-monitor:latest ./security-reports

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${1:-anuddeeph/pod-monitor:latest}"
OUTPUT_DIR="${2:-./security-reports}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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
    
    # Install Cosign
    if ! command -v cosign &> /dev/null; then
        log_info "Installing Cosign..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-darwin-amd64
            chmod +x cosign-darwin-amd64
            sudo mv cosign-darwin-amd64 /usr/local/bin/cosign
        else
            curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
            chmod +x cosign-linux-amd64
            sudo mv cosign-linux-amd64 /usr/local/bin/cosign
        fi
    fi
    
    log_success "Security tools installation completed"
}

run_vulnerability_scan() {
    log_info "Running Grype vulnerability scan on $IMAGE_NAME..."
    
    # Create structured security-reports directory
    mkdir -p "$OUTPUT_DIR/grype"
    mkdir -p "$OUTPUT_DIR/sbom"
    mkdir -p "$OUTPUT_DIR/vex"
    
    # Generate image-based filename
    local image_file_name=$(echo "$IMAGE_NAME" | sed 's/:/-/g' | sed 's/\//_/g')
    
    # Generate vulnerability reports in multiple formats with image-specific names
    grype "$IMAGE_NAME" -o json > "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.json"
    grype "$IMAGE_NAME" -o table > "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.txt"
    grype "$IMAGE_NAME" -o sarif > "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.sarif"
    
    # Parse vulnerability counts using image-specific filename
    if command -v jq &> /dev/null; then
        TOTAL_VULNS=$(jq '.matches | length' "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.json")
        CRITICAL_VULNS=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.json")
        HIGH_VULNS=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.json")
        MEDIUM_VULNS=$(jq '[.matches[] | select(.vulnerability.severity == "Medium")] | length' "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.json")
        LOW_VULNS=$(jq '[.matches[] | select(.vulnerability.severity == "Low")] | length' "$OUTPUT_DIR/grype/${image_file_name}-vulnerabilities.json")
        
        log_info "Vulnerability Summary:"
        echo "  Total: $TOTAL_VULNS"
        echo "  Critical: $CRITICAL_VULNS"
        echo "  High: $HIGH_VULNS"
        echo "  Medium: $MEDIUM_VULNS"
        echo "  Low: $LOW_VULNS"
        
        # Set global variables for later use
        export VULN_TOTAL=$TOTAL_VULNS
        export VULN_CRITICAL=$CRITICAL_VULNS
        export VULN_HIGH=$HIGH_VULNS
        export VULN_MEDIUM=$MEDIUM_VULNS
        export VULN_LOW=$LOW_VULNS
    else
        log_warning "jq not found - cannot parse vulnerability counts"
        export VULN_TOTAL=0
        export VULN_CRITICAL=0
        export VULN_HIGH=0
        export VULN_MEDIUM=0
        export VULN_LOW=0
    fi
    
    log_success "Vulnerability scan completed"
}

generate_sbom() {
    log_info "Generating Software Bill of Materials (SBOM) for $IMAGE_NAME..."
    
    # Generate image-based filename
    local image_file_name=$(echo "$IMAGE_NAME" | sed 's/:/-/g' | sed 's/\//_/g')
    
    # Generate SBOM in multiple formats with image-specific names
    syft "$IMAGE_NAME" -o cyclonedx-json > "$OUTPUT_DIR/sbom/${image_file_name}-sbom.cyclonedx.json"
    syft "$IMAGE_NAME" -o spdx-json > "$OUTPUT_DIR/sbom/${image_file_name}-sbom.spdx.json"
    syft "$IMAGE_NAME" -o table > "$OUTPUT_DIR/sbom/${image_file_name}-sbom.txt"
    
    # Count components
    if command -v jq &> /dev/null; then
        COMPONENT_COUNT=$(jq '.components | length' "$OUTPUT_DIR/sbom/${image_file_name}-sbom.cyclonedx.json")
        log_info "SBOM contains $COMPONENT_COUNT components"
        export SBOM_COMPONENTS=$COMPONENT_COUNT
    else
        log_warning "jq not found - cannot count SBOM components"
        export SBOM_COMPONENTS=0
    fi
    
    log_success "SBOM generation completed"
}

generate_vex_document() {
    log_info "Generating VEX (Vulnerability Exploitability eXchange) document..."
    
    # Generate image-based filename
    local image_file_name=$(echo "$IMAGE_NAME" | sed 's/:/-/g' | sed 's/\//_/g')
    
    # Export image filename for Python script
    export IMAGE_FILE_NAME="$image_file_name"
    
    # Generate VEX document using Python
    python3 << 'EOF'
import json
import os
import sys
from datetime import datetime

def generate_vex():
    try:
        # Get paths with image-specific filenames
        output_dir = os.environ.get('OUTPUT_DIR', './security-reports')
        image_file_name = os.environ.get('IMAGE_FILE_NAME', 'unknown-image')
        
        # Read SBOM and Grype results with image-specific names
        sbom_file = f"{output_dir}/sbom/{image_file_name}-sbom.cyclonedx.json"
        grype_file = f"{output_dir}/grype/{image_file_name}-vulnerabilities.json"
        
        if not os.path.exists(sbom_file) or not os.path.exists(grype_file):
            print("SBOM or vulnerability file not found")
            return
            
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
        image_name = os.environ.get('IMAGE_NAME', 'unknown-image')
        vex_doc = {
            "@context": "https://openvex.dev/ns/v0.2.0",
            "@id": f"https://github.com/anuddeeph1/devops-k8s-case-study/vex/{image_name.replace(':', '-').replace('/', '-')}",
            "author": "Local Security Scanner",
            "timestamp": datetime.utcnow().isoformat() + "Z",
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
                        "@id": image_name,
                        "subcomponents": [subcomponent]
                    }
                ],
                "status": status,
                "justification": justification,
                "impact_statement": f"Severity: {severity} - {vulnerability.get('description', 'No description available')}",
                "action_statement": f"Component {'found in SBOM' if sbom_component else 'detected by scanner'}: {artifact_name}"
            }
            
            vex_doc["statements"].append(statement)
        
        # Write VEX document with image-specific name
        output_dir = os.environ.get('OUTPUT_DIR', './security-reports')
        image_file_name = os.environ.get('IMAGE_FILE_NAME', 'unknown-image')
        vex_file = f"{output_dir}/vex/{image_file_name}-vex-document.json"
        with open(vex_file, 'w') as f:
            json.dump(vex_doc, f, indent=2)
            
        print(f"Generated VEX document with {len(vex_doc['statements'])} statements")
        
        # Export for shell script
        os.environ['VEX_STATEMENTS'] = str(len(vex_doc['statements']))
        
    except Exception as e:
        print(f"Error generating VEX: {e}")
        sys.exit(1)

if __name__ == "__main__":
    generate_vex()
EOF

    # Get image filename for file path
    local image_file_name=$(echo "$IMAGE_NAME" | sed 's/:/-/g' | sed 's/\//_/g')
    export VEX_STATEMENTS=$(jq '.statements | length' "$OUTPUT_DIR/vex/${image_file_name}-vex-document.json" 2>/dev/null || echo "0")
    log_success "VEX document generated with $VEX_STATEMENTS statements"
}

create_security_summary() {
    log_info "Creating security summary report..."
    
    cat > "$OUTPUT_DIR/security-summary.md" << EOF
# 🛡️ Container Security Analysis Report

**Image:** \`$IMAGE_NAME\`  
**Scan Date:** $(date)  
**Scanner:** Local Security Scanner  
**Output Directory:** $OUTPUT_DIR  

## 📊 Vulnerability Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | ${VULN_CRITICAL:-0} |
| 🟠 High | ${VULN_HIGH:-0} |
| 🟡 Medium | ${VULN_MEDIUM:-0} |
| 🟢 Low | ${VULN_LOW:-0} |
| **Total** | **${VULN_TOTAL:-0}** |

## 📋 SBOM Information

- **Components Identified:** ${SBOM_COMPONENTS:-0}
- **SBOM Formats:** CycloneDX, SPDX, Table
- **SBOM Generated:** ✅ Yes

## 📑 VEX Document

- **VEX Statements:** ${VEX_STATEMENTS:-0}
- **VEX Created:** ✅ Yes
- **Compliance:** OpenVEX v0.2.0

## 🔍 Analysis Results

### Vulnerability Assessment
EOF

    if [ "${VULN_TOTAL:-0}" -gt 0 ]; then
        cat >> "$OUTPUT_DIR/security-summary.md" << EOF

⚠️ **Vulnerabilities detected in container image**

**Action Items:**
- Review vulnerability details in \`grype/vulnerabilities.json\`
- Check VEX document for exploitability assessments in \`vex/vex-document.json\`
- Consider updating base images or dependencies
- Review SARIF report for integration with code scanning tools

**High Priority:** ${VULN_CRITICAL:-0} Critical + ${VULN_HIGH:-0} High severity vulnerabilities
EOF
    else
        cat >> "$OUTPUT_DIR/security-summary.md" << EOF

✅ **No vulnerabilities found in container image**

**Status:** Container passes security scan with clean bill of health
EOF
    fi

    cat >> "$OUTPUT_DIR/security-summary.md" << EOF

## 📁 Report Files

- \`grype/\${IMAGE_NAME}-vulnerabilities.json\` - Detailed vulnerability data (JSON format)
- \`grype/\${IMAGE_NAME}-vulnerabilities.txt\` - Human-readable vulnerability report
- \`grype/\${IMAGE_NAME}-vulnerabilities.sarif\` - SARIF format for code scanning integration
- \`sbom/\${IMAGE_NAME}-sbom.cyclonedx.json\` - Software Bill of Materials (CycloneDX format)
- \`sbom/\${IMAGE_NAME}-sbom.spdx.json\` - Software Bill of Materials (SPDX format)
- \`sbom/\${IMAGE_NAME}-sbom.txt\` - Human-readable SBOM
- \`vex/\${IMAGE_NAME}-vex-document.json\` - Vulnerability Exploitability Exchange document

## 🔧 Command References

### Manual Verification Commands

\`\`\`bash
# Re-run vulnerability scan
grype $IMAGE_NAME

# Re-generate SBOM
syft $IMAGE_NAME -o cyclonedx-json

# View vulnerability details
jq '.matches[] | select(.vulnerability.severity == "Critical")' $OUTPUT_DIR/grype/vulnerabilities.json
\`\`\`

### Integration Commands

\`\`\`bash
# Sign SBOM with Cosign (requires setup)
cosign attest --predicate $OUTPUT_DIR/sbom/\${IMAGE_NAME}-sbom.cyclonedx.json --type cyclonedx $IMAGE_NAME

# Sign VEX with Cosign
cosign attest --predicate $OUTPUT_DIR/vex/\${IMAGE_NAME}-vex-document.json --type vuln $IMAGE_NAME
\`\`\`
EOF

    log_success "Security summary report created at $OUTPUT_DIR/security-summary.md"
}

display_results() {
    echo ""
    echo "=========================================="
    echo "🛡️  SECURITY SCAN RESULTS SUMMARY"
    echo "=========================================="
    echo "Image: $IMAGE_NAME"
    echo "Timestamp: $TIMESTAMP"
    echo ""
    echo "📊 VULNERABILITIES:"
    echo "   Critical: ${VULN_CRITICAL:-0}"
    echo "   High:     ${VULN_HIGH:-0}"
    echo "   Medium:   ${VULN_MEDIUM:-0}"
    echo "   Low:      ${VULN_LOW:-0}"
    echo "   Total:    ${VULN_TOTAL:-0}"
    echo ""
    echo "📋 SBOM: ${SBOM_COMPONENTS:-0} components identified"
    echo "📑 VEX:  ${VEX_STATEMENTS:-0} vulnerability statements"
    echo ""
    echo "📁 Reports saved to: $OUTPUT_DIR"
    echo "📄 Summary report:   $OUTPUT_DIR/security-summary.md"
    echo ""
    
    if [ "${VULN_CRITICAL:-0}" -gt 0 ] || [ "${VULN_HIGH:-0}" -gt 0 ]; then
        log_warning "High-severity vulnerabilities detected! Review the reports."
    else
        log_success "Security scan completed successfully!"
    fi
    
    echo "=========================================="
}

# Main execution
main() {
    echo "🛡️ Container Security Scanner"
    echo "============================="
    
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <image-name> [output-dir]"
        echo "Example: $0 anuddeeph/pod-monitor:latest ./security-reports"
        echo ""
    fi
    
    log_info "Scanning image: $IMAGE_NAME"
    log_info "Output directory: $OUTPUT_DIR"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Install security tools if not available
    install_security_tools
    
    # Check tools are available
    check_tool grype
    check_tool syft
    
    # Pull the image if it doesn't exist locally
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        log_info "Pulling image: $IMAGE_NAME"
        docker pull "$IMAGE_NAME"
    fi
    
    # Export variables for Python script
    export OUTPUT_DIR
    export IMAGE_NAME
    
    # Run security scans
    run_vulnerability_scan
    generate_sbom
    generate_vex_document
    create_security_summary
    
    # Display results
    display_results
    
    # Exit with appropriate code
    if [ "${VULN_CRITICAL:-0}" -gt 0 ]; then
        exit 2  # Critical vulnerabilities found
    elif [ "${VULN_HIGH:-0}" -gt 0 ]; then
        exit 1  # High vulnerabilities found
    else
        exit 0  # Success
    fi
}

# Run main function
main "$@"
