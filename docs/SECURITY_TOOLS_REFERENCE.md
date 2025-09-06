# 🔧 Security Tools Reference Guide

> **Comprehensive reference for Grype, Syft, VEX, and Cosign tools implementation**

## 📋 Table of Contents

- [🔍 Grype - Vulnerability Scanner](#-grype---vulnerability-scanner)
- [📋 Syft - SBOM Generator](#-syft---sbom-generator)  
- [📑 VEX - Vulnerability Exploitability Exchange](#-vex---vulnerability-exploitability-exchange)
- [🔏 Cosign - Container Signing](#-cosign---container-signing)
- [🛠️ Installation Guide](#️-installation-guide)
- [📖 Command Reference](#-command-reference)
- [🔧 Configuration](#-configuration)
- [📊 Output Formats](#-output-formats)

## 🔍 Grype - Vulnerability Scanner

### Overview
Grype is a vulnerability scanner for container images and filesystems. It's designed to be fast, accurate, and easy to integrate into CI/CD pipelines.

### Key Features
- **Multi-source vulnerability database** - CVE, Alpine SecDB, Red Hat Security Advisories, etc.
- **Multiple scan targets** - Container images, directories, files, SBOMs
- **Rich output formats** - JSON, Table, SARIF, CycloneDX
- **Configurable matching** - Language-specific and distro-specific matching
- **CI/CD optimized** - Fast scans with caching support

### Installation
```bash
# Install latest version
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Install specific version
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin v0.74.0

# Verify installation
grype version
```

### Basic Usage
```bash
# Scan a container image
grype ubuntu:20.04

# Scan with specific output format
grype ubuntu:20.04 -o json

# Scan and fail on severity
grype ubuntu:20.04 --fail-on high

# Scan using SBOM input
grype sbom:./sbom.json
```

### Advanced Configuration
```yaml
# .grype.yaml
output: "json"
file: "./grype-report.json"
distro: "ubuntu:20.04"
fail-on-severity: "medium"
only-fixed: true

match:
  java:
    using-cpes: false
  javascript:
    using-cpes: false

ignore:
  - vulnerability: "CVE-2008-4225"
    fix-state: "unknown"
  - vulnerability: "CVE-2022-*"
    package:
      name: "libxml2"
      version: "2.9.10*"
```

### Output Formats
```bash
# Table format (default)
grype image:tag

# JSON format
grype image:tag -o json

# SARIF format for GitHub Security
grype image:tag -o sarif

# Template format
grype image:tag -o template -t custom-template.tmpl
```

### Database Management
```bash
# Update vulnerability database
grype db update

# Check database status
grype db status

# List database metadata
grype db list

# Import custom database
grype db import ./custom-db.tar.gz
```

## 📋 Syft - SBOM Generator

### Overview
Syft generates Software Bills of Materials (SBOM) from container images and filesystems. It discovers packages, libraries, and dependencies across multiple ecosystems.

### Key Features
- **Multi-ecosystem support** - Alpine, Debian, RPM, Python, JavaScript, Java, Go, Rust, etc.
- **Multiple output formats** - SPDX, CycloneDX, JSON, Table
- **Flexible cataloging** - File-based and package-manager-based discovery
- **Rich metadata** - Licenses, vulnerabilities, file locations
- **Fast scanning** - Optimized for CI/CD performance

### Installation
```bash
# Install latest version
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install specific version
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin v0.95.0

# Verify installation
syft version
```

### Basic Usage
```bash
# Generate SBOM for container image
syft ubuntu:20.04

# Generate SBOM in SPDX format
syft ubuntu:20.04 -o spdx-json

# Generate SBOM in CycloneDX format
syft ubuntu:20.04 -o cyclonedx-json

# Scan directory
syft ./my-project
```

### Advanced Configuration
```yaml
# .syft.yaml
file: "sbom.json"
output: "cyclonedx-json"
quiet: false

package:
  cataloger:
    enabled: true
    scope: "squashed"
  
  search-unindexed-archives: true
  search-indexed-archives: true

catalogers:
  - "alpmdb"
  - "apkdb"  
  - "dpkgdb"
  - "rpmdb"
  - "python-package"
  - "javascript-package"
  - "java-archive"
  - "go-module-binary"

file-metadata:
  cataloger:
    enabled: false
    scope: "squashed"
  
  digests: ["sha256", "md5"]

file-classification:
  cataloger:
    enabled: false
    scope: "squashed"

file-contents:
  cataloger:
    enabled: false
    scope: "squashed"
  
  skip-files-above-size: 1048576
  globs: []
```

### Output Formats Comparison

| Format | Use Case | Standard | Vulnerability Data |
|--------|----------|----------|-------------------|
| **CycloneDX** | Industry standard, comprehensive | OWASP CycloneDX | Yes |
| **SPDX** | Linux Foundation standard | SPDX 2.2+ | Limited |
| **JSON** | Syft native format | Syft-specific | Yes |
| **Table** | Human readable | N/A | No |

### Cataloger Selection
```bash
# Use specific catalogers
syft image:tag --catalogers apkdb,dpkgdb

# List available catalogers
syft catalogers

# Disable specific catalogers  
syft image:tag --catalogers=-javascript-package
```

## 📑 VEX - Vulnerability Exploitability Exchange

### Overview
VEX (Vulnerability Exploitability eXchange) provides a standardized format for communicating the exploitability status of vulnerabilities in software components.

### Key Concepts
- **VEX Statements** - Assessments of vulnerability impact
- **Products** - Software components being assessed
- **Subcomponents** - Dependencies and sub-packages
- **Status Values** - not_affected, affected, fixed, under_investigation

### VEX Status Values

| Status | Description | Use Case |
|--------|-------------|----------|
| **not_affected** | Product not impacted by vulnerability | False positives, unused code paths |
| **affected** | Product is impacted | Confirmed vulnerabilities |
| **fixed** | Vulnerability has been remediated | Patches applied |
| **under_investigation** | Impact being assessed | New vulnerabilities |

### VEX Justifications

| Justification | Description |
|---------------|-------------|
| **component_not_present** | Vulnerable component not included |
| **vulnerable_code_not_present** | Specific vulnerable code not present |
| **vulnerable_code_not_in_execute_path** | Code present but not executed |
| **vulnerable_code_cannot_be_controlled_by_adversary** | Code not exploitable |
| **inline_mitigations_already_exist** | Protections in place |

### VEX Document Structure
```json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://example.com/vex/product-v1.0",
  "author": "Security Team",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": 1,
  "statements": [
    {
      "vulnerability": {
        "name": "CVE-2023-1234",
        "description": "Buffer overflow vulnerability"
      },
      "products": [
        {
          "@id": "pkg:container/myapp@v1.0",
          "subcomponents": [
            {
              "@id": "pkg:apk/alpine/libssl@1.1.1k",
              "name": "libssl",
              "version": "1.1.1k"
            }
          ]
        }
      ],
      "status": "not_affected",
      "justification": "vulnerable_code_not_in_execute_path",
      "impact_statement": "The vulnerable function is not used in our application",
      "action_statement": "No action required - code path not accessible"
    }
  ]
}
```

### VEX Generation Example
```python
import json
from datetime import datetime

def create_vex_statement(cve_id, product_id, status, justification):
    return {
        "vulnerability": {"name": cve_id},
        "products": [{"@id": product_id}],
        "status": status,
        "justification": justification,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

vex_doc = {
    "@context": "https://openvex.dev/ns/v0.2.0",
    "@id": "https://example.com/vex/myapp-v1.0",
    "author": "Security Team",
    "timestamp": datetime.utcnow().isoformat() + "Z",
    "version": 1,
    "statements": [
        create_vex_statement(
            "CVE-2023-1234",
            "pkg:container/myapp@v1.0",
            "not_affected",
            "component_not_present"
        )
    ]
}
```

## 🔏 Cosign - Container Signing

### Overview
Cosign provides container signing, verification, and attestation in an OCI registry. It supports keyless signing with OIDC and traditional key-based signing.

### Key Features
- **Keyless signing** - OIDC-based signing with Sigstore
- **Key-based signing** - Traditional cryptographic keys
- **Attestation** - SLSA provenance, SBOM, custom attestations
- **Policy enforcement** - Admission controllers and policy engines
- **Registry integration** - OCI-compliant registry support

### Installation
```bash
# Install latest version
curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Install via package manager
# Debian/Ubuntu
curl -1sLf 'https://dl.cloudsmith.io/public/sigstore/cosign/setup.deb.sh' | sudo -E bash
sudo apt install cosign

# Verify installation
cosign version
```

### Basic Usage
```bash
# Generate key pair
cosign generate-key-pair

# Sign image with generated keys
cosign sign --key cosign.key image:tag

# Sign image with keyless (OIDC)
cosign sign image:tag

# Verify signature
cosign verify --key cosign.pub image:tag

# Verify with keyless
cosign verify image:tag
```

### Attestation Operations
```bash
# Attest SBOM to image
cosign attest --predicate sbom.json --type cyclonedx image:tag

# Attest custom statement
cosign attest --predicate statement.json --type custom image:tag

# Verify attestation
cosign verify-attestation --type cyclonedx image:tag

# View attestation tree
cosign tree image:tag
```

### Advanced Configuration
```yaml
# cosign.yaml
fulcio-url: "https://fulcio.sigstore.dev"
rekor-url: "https://rekor.sigstore.dev"
ctlog-pub-key: "/path/to/ctlog.pub"
signature-annotation:
  - "build-date=2024-01-15"
  - "builder=github-actions"
```

### OIDC Providers
```bash
# GitHub Actions
export COSIGN_EXPERIMENTAL=1
cosign sign image:tag

# Google Cloud
gcloud auth application-default login
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
cosign sign --oidc-issuer https://accounts.google.com image:tag

# Custom OIDC
cosign sign --oidc-issuer https://custom-oidc.com image:tag
```

## 🛠️ Installation Guide

### System Requirements
- **OS**: Linux, macOS, Windows
- **Architecture**: x86_64, ARM64
- **Memory**: 512MB+ recommended
- **Disk**: 100MB+ for databases and cache

### Automated Installation Script
```bash
#!/bin/bash
# install-security-tools.sh

set -e

echo "Installing container security tools..."

# Install Grype
echo "Installing Grype..."
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Install Syft
echo "Installing Syft..."
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Cosign
echo "Installing Cosign..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-darwin-amd64
    chmod +x cosign-darwin-amd64
    sudo mv cosign-darwin-amd64 /usr/local/bin/cosign
else
    curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
    chmod +x cosign-linux-amd64
    sudo mv cosign-linux-amd64 /usr/local/bin/cosign
fi

echo "Verifying installations..."
grype version
syft version  
cosign version

echo "Security tools installed successfully!"
```

### Docker-based Usage
```bash
# Run Grype in container
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/grype:latest image:tag

# Run Syft in container  
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/syft:latest image:tag

# Run Cosign in container
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  gcr.io/projectsigstore/cosign:latest sign image:tag
```

## 📖 Command Reference

### Grype Commands
```bash
# Scanning
grype <target>                          # Scan target
grype <target> -o <format>              # Scan with output format
grype <target> --fail-on <severity>     # Fail on severity level
grype <target> --only-fixed             # Only show fixed vulnerabilities

# Database
grype db update                         # Update vulnerability database
grype db status                         # Show database status
grype db list                          # List database metadata

# Configuration  
grype <target> --config <config-file>   # Use config file
grype <target> --add-cpes-if-none       # Add CPEs when missing
```

### Syft Commands
```bash
# SBOM Generation
syft <target>                           # Generate SBOM
syft <target> -o <format>               # Generate with format
syft <target> --catalogers <list>       # Use specific catalogers
syft <target> --scope <scope>           # Set catalog scope

# Formats
syft <target> -o cyclonedx-json         # CycloneDX JSON
syft <target> -o spdx-json              # SPDX JSON  
syft <target> -o table                  # Human readable

# Advanced
syft catalogers                         # List available catalogers
syft <target> --file <output>           # Save to file
```

### Cosign Commands
```bash
# Signing
cosign generate-key-pair                # Generate key pair
cosign sign --key <key> <image>         # Sign with key
cosign sign <image>                     # Keyless signing

# Verification
cosign verify --key <key> <image>       # Verify with key
cosign verify <image>                   # Keyless verification
cosign tree <image>                     # Show signature tree

# Attestation
cosign attest --predicate <file> --type <type> <image>  # Create attestation
cosign verify-attestation --type <type> <image>         # Verify attestation
```

## 🔧 Configuration

### Environment Variables

#### Grype
```bash
export GRYPE_DB_CACHE_DIR=/tmp/grype-db       # Database cache directory
export GRYPE_DB_UPDATE_URL=<url>              # Custom database URL
export GRYPE_DB_VALIDATE_BY_HASH_ON_START=true # Validate DB on startup
export GRYPE_PLATFORM=linux/amd64             # Target platform
```

#### Syft
```bash
export SYFT_PLATFORM=linux/amd64              # Target platform
export SYFT_CATALOGER_SCOPE=squashed          # Catalog scope
export SYFT_PACKAGE_SEARCH_UNINDEXED_ARCHIVES=true # Search archives
```

#### Cosign
```bash
export COSIGN_EXPERIMENTAL=1                  # Enable keyless features
export COSIGN_REPOSITORY=<registry>           # Signature repository
export SIGSTORE_FULCIO_URL=<url>              # Fulcio CA URL
export SIGSTORE_REKOR_URL=<url>               # Rekor transparency log URL
```

### Configuration Files

#### Grype Configuration
```yaml
# ~/.grype.yaml or .grype.yaml
output: "json"
file: ""
distro: ""
add-cpes-if-none: false
output-template-file: ""
quiet: false
check-for-app-update: true

fail-on-severity: ""
only-fixed: false
only-notfixed: false
ignore-wontfix: true

platform: ""
search:
  unindexed-archives: true
  indexed-archives: true

ignore:
  - vulnerability: "CVE-2008-4225"
  - vulnerability: "CVE-2013-*"
    fix-state: "wont-fix"

match:
  java:
    using-cpes: false
  dotnet:
    using-cpes: false
  javascript:  
    using-cpes: false
  python:
    using-cpes: false
  ruby:
    using-cpes: false
  rust:
    using-cpes: false
  stock:
    using-cpes: true
```

#### Syft Configuration
```yaml
# ~/.syft.yaml or .syft.yaml
output: "cyclonedx-json"
file: ""
quiet: false
log:
  level: "info"

package:
  cataloger:
    enabled: true
    scope: "squashed"
  search-unindexed-archives: true
  search-indexed-archives: true

file-metadata:
  cataloger:
    enabled: false
    scope: "squashed"
  digests: ["sha1", "md5", "sha256"]

file-contents:
  cataloger:
    enabled: false
    scope: "squashed"
  skip-files-above-size: 1048576
  globs: []

catalogers:
  - "alpmdb"
  - "apkdb"
  - "dpkgdb"
  - "portage"
  - "rpmdb"
  - "python-package"
  - "javascript-package"
  - "java-archive"
  - "go-module-binary"
```

## 📊 Output Formats

### Grype Output Formats

#### JSON Format
```json
{
  "matches": [
    {
      "vulnerability": {
        "id": "CVE-2023-1234",
        "dataSource": "https://security-tracker.debian.org/tracker/CVE-2023-1234",
        "namespace": "debian:distro:debian:11",
        "severity": "High",
        "urls": ["https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2023-1234"],
        "description": "Vulnerability description",
        "cvss": [
          {
            "version": "3.1",
            "vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
            "metrics": {
              "baseScore": 9.8,
              "exploitabilityScore": 3.9,
              "impactScore": 5.9
            }
          }
        ],
        "fix": {
          "versions": ["1.2.3"],
          "state": "fixed"
        }
      },
      "relatedVulnerabilities": [],
      "matchDetails": [
        {
          "type": "exact-direct-match",
          "matcher": "dpkg-matcher",
          "searchedBy": {
            "distro": {
              "type": "debian",
              "version": "11"
            }
          },
          "found": {
            "versionConstraint": "< 1.2.3 (deb)"
          }
        }
      ],
      "artifact": {
        "name": "libssl1.1",
        "version": "1.1.1k-1",
        "type": "deb",
        "locations": [
          {
            "path": "/var/lib/dpkg/status",
            "layerID": "sha256:abc123"
          }
        ],
        "language": "",
        "licenses": [],
        "cpes": ["cpe:2.3:a:openssl:openssl:1.1.1k:*:*:*:*:*:*:*"],
        "purl": "pkg:deb/debian/libssl1.1@1.1.1k-1?arch=amd64&distro=debian-11",
        "upstreams": []
      }
    }
  ],
  "source": {
    "type": "image",
    "target": {
      "userInput": "ubuntu:20.04",
      "imageID": "sha256:def456",
      "manifestDigest": "sha256:ghi789",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "tags": ["ubuntu:20.04"],
      "imageSize": 72897596,
      "layers": [
        {
          "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
          "digest": "sha256:jkl012",
          "size": 72897596
        }
      ],
      "manifest": "...",
      "config": "...",
      "repoDigests": ["ubuntu@sha256:mno345"]
    }
  },
  "distro": {
    "name": "ubuntu",
    "version": "20.04",
    "idLike": ["debian"]
  },
  "descriptor": {
    "name": "grype",
    "version": "0.74.0",
    "configuration": {
      "output": "json",
      "file": "",
      "distro": "",
      "add-cpes-if-none": false,
      "output-template-file": "",
      "quiet": false,
      "check-for-app-update": true,
      "only-fixed": false,
      "only-notfixed": false,
      "ignore-wontfix": true,
      "platform": "",
      "search": {
        "unindexed-archives": true,
        "indexed-archives": true
      },
      "ignore": [],
      "catalogers": null,
      "match": {
        "java": {
          "using-cpes": false
        },
        "dotnet": {
          "using-cpes": false  
        },
        "javascript": {
          "using-cpes": false
        },
        "python": {
          "using-cpes": false
        },
        "ruby": {
          "using-cpes": false
        },
        "rust": {
          "using-cpes": false
        },
        "stock": {
          "using-cpes": true
        }
      }
    },
    "db": {
      "built": "2024-01-15T08:30:45Z",
      "schemaVersion": 5,
      "location": "/home/user/.cache/grype/db/5",
      "checksum": "sha256:pqr678",
      "error": null
    }
  }
}
```

#### SARIF Format
```json
{
  "version": "2.1.0",
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "grype",
          "version": "0.74.0",
          "informationUri": "https://github.com/anchore/grype",
          "rules": [
            {
              "id": "CVE-2023-1234-libssl1.1",
              "shortDescription": {
                "text": "CVE-2023-1234 in libssl1.1"
              },
              "fullDescription": {
                "text": "Vulnerability description"
              },
              "help": {
                "text": "The installed version of libssl1.1 is vulnerable to CVE-2023-1234."
              },
              "properties": {
                "security-severity": "9.8"
              }
            }
          ]
        }
      },
      "results": [
        {
          "ruleId": "CVE-2023-1234-libssl1.1",
          "level": "error",
          "message": {
            "text": "The installed version of libssl1.1 is vulnerable to CVE-2023-1234"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "/var/lib/dpkg/status"
                },
                "region": {
                  "startLine": 1,
                  "startColumn": 1,
                  "endLine": 1,
                  "endColumn": 1
                }
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### Syft Output Formats

#### CycloneDX Format
```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "serialNumber": "urn:uuid:12345678-1234-5678-9012-123456789012",
  "version": 1,
  "metadata": {
    "timestamp": "2024-01-15T10:30:00Z",
    "tools": [
      {
        "vendor": "anchore",
        "name": "syft",
        "version": "0.95.0"
      }
    ],
    "component": {
      "bom-ref": "12345678-1234-5678-9012-123456789012",
      "type": "container",
      "name": "ubuntu",
      "version": "20.04"
    }
  },
  "components": [
    {
      "bom-ref": "pkg:deb/ubuntu/base-files@11.1ubuntu2.2",
      "type": "library",
      "name": "base-files",
      "version": "11.1ubuntu2.2",
      "licenses": [
        {
          "license": {
            "name": "GPL-3.0"
          }
        }
      ],
      "purl": "pkg:deb/ubuntu/base-files@11.1ubuntu2.2?arch=amd64&distro=ubuntu-20.04",
      "properties": [
        {
          "name": "syft:package:foundBy",
          "value": "dpkgdb-cataloger"
        },
        {
          "name": "syft:package:metadataType",  
          "value": "DpkgMetadata"
        },
        {
          "name": "syft:cpe23",
          "value": "cpe:2.3:a:base-files:base-files:11.1ubuntu2.2:*:*:*:*:*:*:*"
        }
      ]
    }
  ]
}
```

#### SPDX Format
```json
{
  "spdxVersion": "SPDX-2.2",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "ubuntu-20.04",
  "documentNamespace": "https://github.com/anchore/syft/ubuntu-20.04-12345678-1234-5678-9012-123456789012",
  "creationInfo": {
    "licenseListVersion": "3.16",
    "creators": ["Tool:syft-0.95.0"],
    "created": "2024-01-15T10:30:00Z"
  },
  "packages": [
    {
      "SPDXID": "SPDXRef-Package-base-files-11.1ubuntu2.2",
      "name": "base-files",
      "versionInfo": "11.1ubuntu2.2",
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "copyrightText": "NOASSERTION",
      "externalRefs": [
        {
          "referenceCategory": "PACKAGE_MANAGER",
          "referenceType": "purl",
          "referenceLocator": "pkg:deb/ubuntu/base-files@11.1ubuntu2.2?arch=amd64&distro=ubuntu-20.04"
        }
      ]
    }
  ],
  "relationships": [
    {
      "spdxElementId": "SPDXRef-DOCUMENT",
      "relationshipType": "DESCRIBES",
      "relatedSpdxElement": "SPDXRef-Package-base-files-11.1ubuntu2.2"
    }
  ]
}
```

---

**🔧 This reference provides comprehensive guidance for implementing and using container security tools in production environments.**
