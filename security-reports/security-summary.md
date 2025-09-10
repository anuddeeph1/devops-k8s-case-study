# 🛡️ Container Security Analysis Report

**Image:** `anuddeeph/pod-monitor:latest-17605449390-110`  
**Scan Date:** Wed Sep 10 06:41:02 UTC 2025  
**Commit:** 81683b6532d3011ea6661b178c759030b344ff7e  
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
