# 🛡️ Multi-Image Container Security Analysis Report

**Scan Date:** 2025-09-10 06:54:27  
**Scanner:** Multi-Image Security Scanner  
**Output Directory:** ./security-reports  
**Timestamp:** 1757487267  

## 📊 Overall Summary

| Metric | Count |
|--------|--------|
| 🖼️ Total Images | 16 |
| ✅ Successfully Scanned | 16 |
| ❌ Failed Scans | 0 |
| 🚨 Total Vulnerabilities | 341 |
| 📋 Total SBOM Components | 33042 |
| 📑 Total VEX Statements | 153 |

## 🖼️ Scanned Images

### Successfully Scanned Images
- **reg.nirmata.io/nirmata/kubectl:1.32.1**
  - Vulnerabilities: 18 (🔴 Critical: 1, 🟠 High: 3, 🟡 Medium: 8, 🟢 Low: 6)
  - SBOM Components: 269  
  - VEX Statements: 10
  - Reports: `reg_nirmata_io_nirmata_kubectl-1_32_1-1757487267-*`
- **reg.nirmata.io/nirmata/cleanup-controller:latest**
  - Vulnerabilities: 23 (🔴 Critical: 3, 🟠 High: 7, 🟡 Medium: 10, 🟢 Low: 3)
  - SBOM Components: 1023  
  - VEX Statements: 7
  - Reports: `reg_nirmata_io_nirmata_cleanup-controller-latest-1757487267-*`
- **reg.nirmata.io/nirmata/reports-server:latest**
  - Vulnerabilities: 0
  - SBOM Components: 1521  
  - VEX Statements: 0
  - Reports: `reg_nirmata_io_nirmata_reports-server-latest-1757487267-*`
- **ghcr.io/nirmata/kubectl:1.30.2**
  - Vulnerabilities: 14 (🔴 Critical: 1, 🟠 High: 6, 🟡 Medium: 7, 🟢 Low: 0)
  - SBOM Components: 1032  
  - VEX Statements: 11
  - Reports: `ghcr_io_nirmata_kubectl-1_30_2-1757487267-*`
- **reg.nirmata.io/nirmata/kubectl:1.31.1**
  - Vulnerabilities: 27 (🔴 Critical: 1, 🟠 High: 7, 🟡 Medium: 13, 🟢 Low: 6)
  - SBOM Components: 264  
  - VEX Statements: 16
  - Reports: `reg_nirmata_io_nirmata_kubectl-1_31_1-1757487267-*`
- **alpine:3.18**
  - Vulnerabilities: 6 (🔴 Critical: 0, 🟠 High: 0, 🟡 Medium: 0, 🟢 Low: 6)
  - SBOM Components: 95  
  - VEX Statements: 2
  - Reports: `alpine-3_18-1757487267-*`
- **nginx:1.25-alpine**
  - Vulnerabilities: 88 (🔴 Critical: 7, 🟠 High: 25, 🟡 Medium: 44, 🟢 Low: 12)
  - SBOM Components: 1402  
  - VEX Statements: 55
  - Reports: `nginx-1_25-alpine-1757487267-*`
- **reg.nirmata.io/nirmata/kyverno:latest**
  - Vulnerabilities: 23 (🔴 Critical: 3, 🟠 High: 7, 🟡 Medium: 10, 🟢 Low: 3)
  - SBOM Components: 1026  
  - VEX Statements: 7
  - Reports: `reg_nirmata_io_nirmata_kyverno-latest-1757487267-*`
- **alpine/curl:latest**
  - Vulnerabilities: 6 (🔴 Critical: 0, 🟠 High: 0, 🟡 Medium: 0, 🟢 Low: 6)
  - SBOM Components: 119  
  - VEX Statements: 2
  - Reports: `alpine_curl-latest-1757487267-*`
- **reg.nirmata.io/nirmata/background-controller:latest**
  - Vulnerabilities: 23 (🔴 Critical: 3, 🟠 High: 7, 🟡 Medium: 10, 🟢 Low: 3)
  - SBOM Components: 1023  
  - VEX Statements: 7
  - Reports: `reg_nirmata_io_nirmata_background-controller-latest-1757487267-*`
- **reg.nirmata.io/nirmata/kyvernopre:latest**
  - Vulnerabilities: 23 (🔴 Critical: 3, 🟠 High: 7, 🟡 Medium: 10, 🟢 Low: 3)
  - SBOM Components: 1022  
  - VEX Statements: 7
  - Reports: `reg_nirmata_io_nirmata_kyvernopre-latest-1757487267-*`
- **busybox:1.35**
  - Vulnerabilities: 5 (🔴 Critical: 1, 🟠 High: 2, 🟡 Medium: 0, 🟢 Low: 2)
  - SBOM Components: 3  
  - VEX Statements: 5
  - Reports: `busybox-1_35-1757487267-*`
- **reg.nirmata.io/nirmata/kyverno-cli:latest**
  - Vulnerabilities: 25 (🔴 Critical: 4, 🟠 High: 8, 🟡 Medium: 10, 🟢 Low: 3)
  - SBOM Components: 1061  
  - VEX Statements: 7
  - Reports: `reg_nirmata_io_nirmata_kyverno-cli-latest-1757487267-*`
- **reg.nirmata.io/nirmata/reports-controller:latest**
  - Vulnerabilities: 23 (🔴 Critical: 3, 🟠 High: 7, 🟡 Medium: 10, 🟢 Low: 3)
  - SBOM Components: 1023  
  - VEX Statements: 7
  - Reports: `reg_nirmata_io_nirmata_reports-controller-latest-1757487267-*`
- **ghcr.io/nirmata/etcd:v3.5.18-cve-free**
  - Vulnerabilities: 27 (🔴 Critical: 3, 🟠 High: 12, 🟡 Medium: 12, 🟢 Low: 0)
  - SBOM Components: 1570  
  - VEX Statements: 5
  - Reports: `ghcr_io_nirmata_etcd-v3_5_18-cve-free-1757487267-*`
- **mysql:8.0**
  - Vulnerabilities: 10 (🔴 Critical: 1, 🟠 High: 4, 🟡 Medium: 5, 🟢 Low: 0)
  - SBOM Components: 20589  
  - VEX Statements: 5
  - Reports: `mysql-8_0-1757487267-*`

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
*Generated at: Wed Sep 10 07:00:01 UTC 2025*
