#!/usr/bin/env python3

"""
Enhanced VEX Generator with Online Intelligence
Generates VEX documents enriched with data from multiple online vulnerability databases
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone

def query_osv_database(cve_id):
    """Query OSV (Open Source Vulnerabilities) Database"""
    try:
        print(f"  🔍 Querying OSV for {cve_id}...", file=sys.stderr)
        url = f"https://api.osv.dev/v1/vulns/{cve_id}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Multi-Image-Security-Scanner/1.0'})
        
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.getcode() == 200:
                data = json.loads(response.read().decode('utf-8'))
                print(f"    ✅ OSV data found for {cve_id}", file=sys.stderr)
                return {
                    "ecosystem_specific": data.get("ecosystem_specific", {}),
                    "database_specific": data.get("database_specific", {}),
                    "severity": data.get("severity", []),
                    "references": data.get("references", []),
                    "affected": data.get("affected", []),
                    "summary": data.get("summary", ""),
                    "details": data.get("details", "")
                }
            else:
                print(f"    ℹ️ No OSV data for {cve_id} (status: {response.getcode()})", file=sys.stderr)
    except Exception as e:
        print(f"    ⚠️ OSV query failed for {cve_id}: {e}", file=sys.stderr)
    return None

def query_cisa_kev():
    """Query CISA Known Exploited Vulnerabilities Catalog"""
    try:
        print("  🔍 Querying CISA KEV catalog...", file=sys.stderr)
        url = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
        req = urllib.request.Request(url, headers={'User-Agent': 'Multi-Image-Security-Scanner/1.0'})
        
        with urllib.request.urlopen(req, timeout=15) as response:
            if response.getcode() == 200:
                kev_data = json.loads(response.read().decode('utf-8'))
                kev_vulns = {v["cveID"]: v for v in kev_data.get("vulnerabilities", [])}
                print(f"    ✅ CISA KEV catalog loaded ({len(kev_vulns)} vulnerabilities)", file=sys.stderr)
                return kev_vulns
            else:
                print(f"    ⚠️ CISA KEV query failed (status: {response.getcode()})", file=sys.stderr)
    except Exception as e:
        print(f"    ⚠️ CISA KEV query failed: {e}", file=sys.stderr)
    return {}

def query_github_advisories(cve_id):
    """Query GitHub Security Advisories"""
    try:
        print(f"  🔍 Querying GitHub Security Advisories for {cve_id}...", file=sys.stderr)
        url = f"https://api.github.com/advisories?cve_id={cve_id}"
        headers = {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'Multi-Image-Security-Scanner/1.0'
        }
        
        # Add GitHub token from environment if available
        github_token = os.environ.get('GITHUB_TOKEN')
        if github_token:
            headers['Authorization'] = f'Bearer {github_token}'
        
        req = urllib.request.Request(url, headers=headers)
        
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.getcode() == 200:
                advisories = json.loads(response.read().decode('utf-8'))
                if advisories:
                    print(f"    ✅ GitHub advisory found for {cve_id}", file=sys.stderr)
                    return advisories[0]  # Return first matching advisory
                else:
                    print(f"    ℹ️ No GitHub advisory for {cve_id}", file=sys.stderr)
            else:
                print(f"    ℹ️ GitHub advisory query failed for {cve_id} (status: {response.getcode()})", file=sys.stderr)
    except Exception as e:
        print(f"    ⚠️ GitHub advisory query failed for {cve_id}: {e}", file=sys.stderr)
    return None

def query_nvd_api(cve_id):
    """Query National Vulnerability Database (NVD) API"""
    try:
        print(f"  🔍 Querying NVD for {cve_id}...", file=sys.stderr)
        url = f"https://services.nvd.nist.gov/rest/json/cves/2.0?cveId={cve_id}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Multi-Image-Security-Scanner/1.0'})
        
        with urllib.request.urlopen(req, timeout=15) as response:
            if response.getcode() == 200:
                data = json.loads(response.read().decode('utf-8'))
                vulnerabilities = data.get("vulnerabilities", [])
                if vulnerabilities:
                    cve_data = vulnerabilities[0].get("cve", {})
                    print(f"    ✅ NVD data found for {cve_id}", file=sys.stderr)
                    return {
                        "description": cve_data.get("descriptions", [{}])[0].get("value", ""),
                        "cvss_v3": cve_data.get("metrics", {}).get("cvssMetricV31", []),
                        "cvss_v2": cve_data.get("metrics", {}).get("cvssMetricV2", []),
                        "references": cve_data.get("references", []),
                        "published": cve_data.get("published", ""),
                        "modified": cve_data.get("lastModified", "")
                    }
                else:
                    print(f"    ℹ️ No NVD data for {cve_id}", file=sys.stderr)
            else:
                print(f"    ℹ️ NVD query failed for {cve_id} (status: {response.getcode()})", file=sys.stderr)
    except Exception as e:
        print(f"    ⚠️ NVD query failed for {cve_id}: {e}", file=sys.stderr)
    return None

def determine_intelligent_vex_status(cve_id, vulnerability, artifact_name, cisa_kev, osv_data, gh_advisory, nvd_data):
    """Determine VEX status based on multiple intelligence sources"""
    severity = vulnerability.get("severity", "Unknown").upper()
    
    # 🚨 CRITICAL: Known Exploited in the Wild (CISA KEV)
    if cve_id in cisa_kev:
        kev_info = cisa_kev[cve_id]
        return {
            "status": "affected",
            "justification": "code_not_present",  # Valid VEX justification
            "impact_statement": f"⚠️ CISA KEV: {kev_info.get('shortDescription', 'Known exploitation detected')} - Due Date: {kev_info.get('dueDate', 'N/A')}",
            "action_statement": f"🚨 CRITICAL: {cve_id} is actively exploited in the wild. Immediate patching required for {artifact_name}. CISA binding directive applies.",
            "intelligence_source": "CISA_KEV"
        }
    
    # 🔍 OSV Database Intelligence
    if osv_data:
        # Check for affected functions or code paths
        affected_packages = osv_data.get("affected", [])
        ecosystem_specific = osv_data.get("ecosystem_specific", {})
        
        for affected in affected_packages:
            if affected.get("package", {}).get("name", "").lower() == artifact_name.lower():
                # Component is directly affected
                if ecosystem_specific.get("affected_functions") or affected.get("ecosystem_specific", {}).get("affected_functions"):
                    return {
                        "status": "under_investigation",
                        "justification": "code_not_reachable",
                        "impact_statement": f"🔬 OSV: Specific functions affected in {artifact_name}. Code analysis required to determine exploitability.",
                        "action_statement": f"📋 Analyze code paths for affected functions in {artifact_name}. OSV indicates specific function-level impact.",
                        "intelligence_source": "OSV_DETAILED"
                    }
                else:
                    return {
                        "status": "under_investigation",
                        "justification": "vulnerable_code_not_in_execute_path",
                        "impact_statement": f"🎯 OSV: {artifact_name} is affected but no specific functions identified. Impact assessment needed.",
                        "action_statement": f"🔍 Component {artifact_name} is listed as affected in OSV. Review usage patterns and update priority.",
                        "intelligence_source": "OSV_AFFECTED"
                    }
    
    # 🐙 GitHub Security Advisory Intelligence
    if gh_advisory:
        severity_gh = gh_advisory.get("severity", "").upper()
        cvss_data = gh_advisory.get("cvss", {})
        cvss_score = 0.0
        
        # Safe CVSS score extraction
        if cvss_data and isinstance(cvss_data, dict):
            score_value = cvss_data.get("score", 0)
            if score_value is not None:
                try:
                    cvss_score = float(score_value)
                except (ValueError, TypeError):
                    cvss_score = 0.0
        
        if severity_gh == "CRITICAL" or cvss_score >= 9.0:
            return {
                "status": "under_investigation",
                "justification": "code_not_reachable",
                "impact_statement": f"🐙 GitHub Advisory: Critical severity (CVSS: {cvss_score}). {gh_advisory.get('summary', 'High impact vulnerability')}",
                "action_statement": f"🔥 Critical GitHub advisory for {artifact_name}. Review {gh_advisory.get('html_url', 'advisory')} and plan immediate update.",
                "intelligence_source": "GITHUB_ADVISORY_CRITICAL"
            }
        elif severity_gh in ["HIGH"] or cvss_score >= 7.0:
            return {
                "status": "under_investigation",
                "justification": "vulnerable_code_not_in_execute_path",
                "impact_statement": f"🐙 GitHub Advisory: High severity (CVSS: {cvss_score}). {gh_advisory.get('summary', 'Significant vulnerability')}",
                "action_statement": f"⚡ High-priority GitHub advisory for {artifact_name}. Schedule update within 7 days.",
                "intelligence_source": "GITHUB_ADVISORY_HIGH"
            }
    
    # 🏛️ NVD CVSS-based Assessment
    if nvd_data:
        cvss_v3_metrics = nvd_data.get("cvss_v3", [])
        if cvss_v3_metrics and len(cvss_v3_metrics) > 0:
            base_score = 0.0
            vector_string = ""
            
            # Safe CVSS data extraction
            if isinstance(cvss_v3_metrics[0], dict):
                cvss_data = cvss_v3_metrics[0].get("cvssData", {})
                if cvss_data and isinstance(cvss_data, dict):
                    score_value = cvss_data.get("baseScore")
                    vector_value = cvss_data.get("vectorString", "")
                    
                    if score_value is not None:
                        try:
                            base_score = float(score_value)
                            vector_string = str(vector_value)
                        except (ValueError, TypeError):
                            base_score = 0.0
                            vector_string = ""
            
            if base_score >= 9.0:
                return {
                    "status": "under_investigation", 
                    "justification": "code_not_reachable",
                    "impact_statement": f"🏛️ NVD: Critical CVSS v3.1 score {base_score}/10. Vector: {vector_string}",
                    "action_statement": f"🔥 NVD rates {cve_id} as critical (CVSS: {base_score}). Immediate assessment required for {artifact_name}.",
                    "intelligence_source": "NVD_CRITICAL"
                }
            elif base_score >= 7.0:
                return {
                    "status": "under_investigation",
                    "justification": "vulnerable_code_not_in_execute_path",
                    "impact_statement": f"🏛️ NVD: High CVSS v3.1 score {base_score}/10. Vector: {vector_string}",
                    "action_statement": f"⚡ NVD rates {cve_id} as high severity (CVSS: {base_score}). Plan update for {artifact_name}.",
                    "intelligence_source": "NVD_HIGH"
                }
    
    # 📊 Fallback: Grype Severity-based Assessment
    if severity in ["CRITICAL", "HIGH"]:
        return {
            "status": "under_investigation",
            "justification": "vulnerable_code_not_in_execute_path",
            "impact_statement": f"📊 Grype: {severity} severity vulnerability. {vulnerability.get('description', 'No detailed description available.')}",
            "action_statement": f"🔍 {severity} severity vulnerability detected by Grype in {artifact_name}. Manual assessment recommended.",
            "intelligence_source": "GRYPE_SEVERITY"
        }
    elif severity == "MEDIUM":
        return {
            "status": "not_affected",
            "justification": "vulnerable_code_not_in_execute_path",
            "impact_statement": f"📊 Grype: Medium severity - likely limited impact. {vulnerability.get('description', 'Standard vulnerability assessment.')}",
            "action_statement": f"📋 Medium severity vulnerability in {artifact_name}. Include in next maintenance cycle.",
            "intelligence_source": "GRYPE_MEDIUM"
        }
    else:
        return {
            "status": "not_affected",
            "justification": "component_not_present",
            "impact_statement": f"📊 Grype: Low/Negligible severity. Minimal impact expected.",
            "action_statement": f"ℹ️ Low-impact vulnerability in {artifact_name}. Monitor for updates during regular maintenance.",
            "intelligence_source": "GRYPE_LOW"
        }

def generate_enhanced_vex(sbom_file, grype_file, output_file, intelligence_summary_file, full_image_name, filename_base):
    """Generate enhanced VEX document with online intelligence"""
    try:
        print(f"🔍 Processing image: {full_image_name}", file=sys.stderr)
        
        with open(sbom_file, 'r') as f:
            sbom_data = json.load(f)
        
        with open(grype_file, 'r') as f:
            grype_data = json.load(f)
        
        # Build component map from SBOM
        print("🔍 Building SBOM component map...", file=sys.stderr)
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
        
        print(f"📦 Found {len(sbom_components)} components in SBOM", file=sys.stderr)
        
        # Load CISA KEV data once (performance optimization)
        print("🌐 Loading CISA Known Exploited Vulnerabilities...", file=sys.stderr)
        cisa_kev_data = query_cisa_kev()
        
        # Create enhanced VEX document structure
        vex_doc = {
            "@context": "https://openvex.dev/ns/v0.2.0",
            "@id": f"https://github.com/devops-k8s-case-study/vex/{filename_base}",
            "author": "Multi-Image Enhanced Security Scanner",
            "timestamp": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            "version": 1,
            "metadata": {
                "intelligence_sources": ["CISA_KEV", "OSV_Database", "GitHub_Security_Advisories", "NVD_API", "Grype_Scanner"],
                "scan_date": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
                "image_analyzed": full_image_name,
                "total_cves_checked": 0,
                "intelligence_gathered": 0
            },
            "statements": []
        }
        
        # Process vulnerabilities with enhanced intelligence
        processed_cves = set()
        cve_count = 0
        intelligence_count = 0
        
        print("🛡️ Processing vulnerabilities with online intelligence...", file=sys.stderr)
        
        for match in grype_data.get("matches", []):
            vulnerability = match.get("vulnerability", {})
            cve_id = vulnerability.get("id", "")
            
            if not cve_id.startswith("CVE-") or cve_id in processed_cves:
                continue
                
            processed_cves.add(cve_id)
            cve_count += 1
            
            print(f"🔍 Analyzing CVE {cve_count}: {cve_id}", file=sys.stderr)
            
            # Get artifact information
            artifact = match.get("artifact", {})
            artifact_name = artifact.get("name", "unknown-component")
            artifact_version = artifact.get("version", "")
            
            # Find matching SBOM component
            search_key = f"{artifact_name}@{artifact_version}".lower() if artifact_version else artifact_name.lower()
            sbom_component = sbom_components.get(search_key)
            
            # Gather intelligence from multiple sources
            osv_data = query_osv_database(cve_id)
            gh_advisory = query_github_advisories(cve_id)
            nvd_data = query_nvd_api(cve_id)
            
            # Count intelligence gathered
            if osv_data or gh_advisory or nvd_data or cve_id in cisa_kev_data:
                intelligence_count += 1
            
            # Rate limiting: small delay between requests
            time.sleep(0.5)
            
            # Determine intelligent VEX status
            vex_assessment = determine_intelligent_vex_status(
                cve_id, vulnerability, artifact_name, cisa_kev_data, osv_data, gh_advisory, nvd_data
            )
            
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
            
            # Create enhanced VEX statement
            statement = {
                "vulnerability": {
                    "name": cve_id,
                    "description": vulnerability.get("description", f"Vulnerability {cve_id}")
                },
                "products": [
                    {
                        "@id": full_image_name,
                        "subcomponents": [subcomponent]
                    }
                ],
                "status": vex_assessment["status"],
                "justification": vex_assessment["justification"],
                "impact_statement": vex_assessment["impact_statement"],
                "action_statement": vex_assessment["action_statement"],
                "metadata": {
                    "intelligence_source": vex_assessment["intelligence_source"],
                    "component_found_in_sbom": sbom_component is not None,
                    "original_severity": vulnerability.get("severity", "Unknown"),
                    "analysis_date": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
                }
            }
            
            vex_doc["statements"].append(statement)
        
        # Update metadata
        vex_doc["metadata"]["total_cves_checked"] = cve_count
        vex_doc["metadata"]["intelligence_gathered"] = intelligence_count
        
        # Write enhanced VEX document
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, 'w') as f:
            json.dump(vex_doc, f, indent=2)
        
        # Generate intelligence summary
        intelligence_summary = {
            "total_vulnerabilities": len(vex_doc["statements"]),
            "affected": sum(1 for s in vex_doc["statements"] if s["status"] == "affected"),
            "under_investigation": sum(1 for s in vex_doc["statements"] if s["status"] == "under_investigation"), 
            "not_affected": sum(1 for s in vex_doc["statements"] if s["status"] == "not_affected"),
            "cisa_kev_matches": sum(1 for s in vex_doc["statements"] if s.get("metadata", {}).get("intelligence_source") == "CISA_KEV"),
            "intelligence_coverage": f"{intelligence_count}/{cve_count}" if cve_count > 0 else "0/0"
        }
        
        with open(intelligence_summary_file, 'w') as f:
            json.dump(intelligence_summary, f, indent=2)
            
        print(f"", file=sys.stderr)
        print(f"✅ Enhanced VEX document generated:", file=sys.stderr)
        print(f"   📄 File: {output_file}", file=sys.stderr)
        print(f"   🔍 CVEs Analyzed: {cve_count}", file=sys.stderr)
        print(f"   🌐 Intelligence Gathered: {intelligence_count}/{cve_count} CVEs", file=sys.stderr)
        print(f"   📊 VEX Statements: {len(vex_doc['statements'])}", file=sys.stderr)
        print(f"   🗃️ SBOM Components: {len(sbom_components)}", file=sys.stderr)
        print(f"   🚨 CISA KEV Matches: {sum(1 for stmt in vex_doc['statements'] if stmt.get('metadata', {}).get('intelligence_source') == 'CISA_KEV')}", file=sys.stderr)
        print(f"", file=sys.stderr)
        
        print(f"📊 Intelligence Summary:", file=sys.stderr)
        print(f"   🚨 Affected (Known Exploited): {intelligence_summary['affected']}", file=sys.stderr)
        print(f"   🔬 Under Investigation: {intelligence_summary['under_investigation']}", file=sys.stderr)
        print(f"   ✅ Not Affected: {intelligence_summary['not_affected']}", file=sys.stderr)
        print(f"   🎯 CISA KEV Critical: {intelligence_summary['cisa_kev_matches']}", file=sys.stderr)
        print(f"   📈 Intelligence Coverage: {intelligence_summary['intelligence_coverage']}", file=sys.stderr)
        
        print(f"Generated enhanced VEX document with {len(vex_doc['statements'])} statements")
        return True
        
    except Exception as e:
        print(f"Error generating enhanced VEX: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if len(sys.argv) != 6:
        print("Usage: python3 enhanced-vex-generator.py <sbom_file> <grype_file> <output_file> <intelligence_summary_file> <full_image_name>", file=sys.stderr)
        sys.exit(1)
    
    sbom_file = sys.argv[1]
    grype_file = sys.argv[2]
    output_file = sys.argv[3]
    intelligence_summary_file = sys.argv[4]
    full_image_name = sys.argv[5]
    filename_base = os.path.basename(output_file).replace('-enhanced-vex-document.json', '')
    
    try:
        if generate_enhanced_vex(sbom_file, grype_file, output_file, intelligence_summary_file, full_image_name, filename_base):
            sys.exit(0)
        else:
            sys.exit(1)
    except Exception as e:
        print(f"Fatal error in enhanced VEX generation: {e}", file=sys.stderr)
        sys.exit(1)
