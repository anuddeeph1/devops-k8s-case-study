# 🛡️ Multi-Image Container Security Analysis Report

**Scan Date:** 2025-09-09 13:05:50  
**Scanner:** Multi-Image Security Scanner  
**Output Directory:** ./security-reports  
**Timestamp:** 1757403350  

## 📊 Overall Summary

| Metric | Count |
|--------|--------|
| 🖼️ Total Images | 1 |
| ✅ Successfully Scanned | 0 |
| ❌ Failed Scans | 1 |
| 🚨 Total Vulnerabilities | 0 |
| 📋 Total SBOM Components | 0 |
| 📑 Total VEX Statements | 0 |

## 🖼️ Scanned Images

### Successfully Scanned Images
- **nirmata/reports-controller:latest**
  - Vulnerabilities: 
  - SBOM Components:   
  - VEX Statements: 0
  - Reports: `nirmata_reports-controller-latest-1757403350-*`

## 📁 Report Files Structure

```
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
```

## 🔧 Usage Examples

### Scan specific severity vulnerabilities
```bash
# Find all critical vulnerabilities across all images
find ./security-reports/grype -name "*.json" -exec jq -r '.matches[] | select(.vulnerability.severity == "Critical") | .vulnerability.id' {} \;

# Count high severity vulnerabilities per image
for f in ./security-reports/grype/*-vulnerabilities.json; do
  echo "File: $(basename $f)"
  jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$f"
done
```

### Analyze SBOM components
```bash
# List all unique component types
find ./security-reports/sbom -name "*-sbom.cyclonedx.json" -exec jq -r '.components[].type' {} \; | sort -u

# Find specific component across all images
find ./security-reports/sbom -name "*-sbom.cyclonedx.json" -exec jq -r '.components[] | select(.name | contains("openssl")) | .name + "@" + .version' {} \;
```

### VEX document analysis
```bash
# Count statements by status across all VEX documents
find ./security-reports/vex -name "*.json" -exec jq -r '.statements[].status' {} \; | sort | uniq -c
```

## 🚀 CI/CD Integration

This scan can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run Multi-Image Security Scan
  run: |
    ./scripts/multi-image-security-scan.sh ./security-reports
    
- name: Upload Security Reports
  uses: actions/upload-artifact@v3
  with:
    name: security-reports-${{ github.run_id }}
    path: security-reports/
```

---
*Generated at: Tue Sep  9 13:06:32 IST 2025*
