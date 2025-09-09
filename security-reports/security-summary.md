# 🛡️ Container Security Analysis Report

**Image:** `anuddeeph/pod-monitor:latest-17586345028-80`  
**Scan Date:** Tue Sep  9 14:43:48 UTC 2025  
**Commit:** 87fb2a4ca1c8906dbb293e9caa07731184749d16  
**Branch:** workflows  

## 📊 Vulnerability Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | 1 |
| 🟠 High | 5 |
| 🟡 Medium | 9 |
| 🟢 Low | 0 |
| **Total** | **15** |

## 📋 SBOM Information

- **Components Identified:** 1434
- **SBOM Formats:** CycloneDX, SPDX, Table
- **SBOM Generated:** ✅ Yes

## 📑 VEX Document

- **VEX Statements:** 10
- **VEX Created:** ✅ Yes
- **Compliance:** OpenVEX v0.2.0

## 🔍 Analysis Results

### Vulnerability Assessment

⚠️ **Vulnerabilities detected in container image**

**Action Items:**
- Review vulnerability details in `vulnerabilities.json`
- Check VEX document for exploitability assessments
- Consider updating base images or dependencies

## 🔒 Attestations

- **SBOM Attestation:** Ready for signing
- **VEX Attestation:** Ready for signing
- **Vulnerability Report:** Available in artifacts

## 📁 Report Files

- `grype/vulnerabilities.json` - Detailed vulnerability data
- `grype/vulnerabilities.sarif` - SARIF format for code scanning
- `sbom/sbom.cyclonedx.json` - Software Bill of Materials
- `vex/vex-document.json` - Vulnerability Exploitability Exchange
