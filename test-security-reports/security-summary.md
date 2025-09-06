# 🛡️ Container Security Analysis Report

**Image:** `alpine:latest`  
**Scan Date:** Sat Sep  6 15:35:23 IST 2025  
**Scanner:** Local Security Scanner  
**Output Directory:** ./test-security-reports  

## 📊 Vulnerability Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | 0 |
| 🟠 High | 0 |
| 🟡 Medium | 0 |
| 🟢 Low | 6 |
| **Total** | **6** |

## 📋 SBOM Information

- **Components Identified:** 98
- **SBOM Formats:** CycloneDX, SPDX, Table
- **SBOM Generated:** ✅ Yes

## 📑 VEX Document

- **VEX Statements:** 2
- **VEX Created:** ✅ Yes
- **Compliance:** OpenVEX v0.2.0

## 🔍 Analysis Results

### Vulnerability Assessment

⚠️ **Vulnerabilities detected in container image**

**Action Items:**
- Review vulnerability details in `grype/vulnerabilities.json`
- Check VEX document for exploitability assessments in `vex/vex-document.json`
- Consider updating base images or dependencies
- Review SARIF report for integration with code scanning tools

**High Priority:** 0 Critical + 0 High severity vulnerabilities

## 📁 Report Files

- `grype/vulnerabilities.json` - Detailed vulnerability data (JSON format)
- `grype/vulnerabilities.txt` - Human-readable vulnerability report
- `grype/vulnerabilities.sarif` - SARIF format for code scanning integration
- `sbom/sbom.cyclonedx.json` - Software Bill of Materials (CycloneDX format)
- `sbom/sbom.spdx.json` - Software Bill of Materials (SPDX format)
- `sbom/sbom.txt` - Human-readable SBOM
- `vex/vex-document.json` - Vulnerability Exploitability Exchange document

## 🔧 Command References

### Manual Verification Commands

```bash
# Re-run vulnerability scan
grype alpine:latest

# Re-generate SBOM
syft alpine:latest -o cyclonedx-json

# View vulnerability details
jq '.matches[] | select(.vulnerability.severity == "Critical")' ./test-security-reports/grype/vulnerabilities.json
```

### Integration Commands

```bash
# Sign SBOM with Cosign (requires setup)
cosign attest --predicate ./test-security-reports/sbom/sbom.cyclonedx.json --type cyclonedx alpine:latest

# Sign VEX with Cosign
cosign attest --predicate ./test-security-reports/vex/vex-document.json --type vuln alpine:latest
```
