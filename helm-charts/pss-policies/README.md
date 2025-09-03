# 🛡️ PSS Policies Helm Chart

> **Kubernetes Pod Security Standards enforcement via Kyverno with configurable Audit/Enforce modes**

## 📋 Overview

The **pss-policies** chart deploys comprehensive Pod Security Standards (PSS) using Kyverno with:
- **17 security policies** (11 Baseline + 6 Restricted)
- **Configurable enforcement** (Audit or Enforce modes)
- **Namespace exclusions** for system components
- **Production-ready templates** with Helm integration
- **GitOps deployment** support via ArgoCD

## 🏗️ Architecture

```
🛡️ Pod Security Standards Enforcement

┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                          │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │  Baseline PSS   │    │ Restricted PSS  │                   │
│  │  (11 policies)  │    │  (6 policies)   │                   │
│  │                 │    │                 │                   │
│  │ • Privileged    │    │ • Non-root      │                   │
│  │ • Capabilities  │    │ • Seccomp       │                   │
│  │ • Host access   │    │ • Volumes       │                   │
│  │ • Security ctx  │    │ • Privilege esc │                   │
│  │ • Sysctls       │    │ • Capabilities  │                   │
│  │ • ...and more   │    │ • Running user  │                   │
│  └─────────────────┘    └─────────────────┘                   │
│           │                       │                           │
│           └───────────┬───────────┘                           │
│                       │                                       │
│              ┌─────────────────┐                              │
│              │ Kyverno Engine  │                              │
│              │ (Policy Engine) │                              │
│              └─────────────────┘                              │
│                       │                                       │
│      ┌────────────────┼────────────────┐                     │
│      │                │                │                     │
│ ✅ devops-case-study  🚫 kube-system   🚫 kyverno           │
│ (PSS Applied)        (Excluded)       (Excluded)             │
│                                                               │
└─────────────────────────────────────────────────────────────────┘

📊 Policy Reports Generated:
├── 📋 PolicyReport (per namespace)
├── 📊 ClusterPolicyReport (cluster-wide)
└── 📈 Metrics for monitoring
```

## ✨ Key Features

### 🔒 **Comprehensive Security Coverage**
- **11 Baseline policies**: Essential security requirements
- **6 Restricted policies**: Enhanced security for sensitive workloads
- **Zero-tolerance approach**: All security violations detected
- **Industry standards**: Based on official Kubernetes PSS

### ⚙️ **Flexible Configuration**
- **Audit mode**: Monitor violations without blocking
- **Enforce mode**: Block non-compliant resources
- **Per-policy configuration**: Granular control
- **Namespace targeting**: Apply to specific namespaces only

### 🚀 **Production Features**
- **Helm templating**: Environment-specific configurations
- **GitOps integration**: Full ArgoCD deployment support
- **Performance optimized**: Background processing
- **Comprehensive reporting**: Detailed violation reports

## 🔧 Configuration

### Default Values (`values.yaml`)

```yaml
# Pod Security Standards configuration
pss:
  # Global policy settings
  validationFailureAction: "Audit"  # Can be "Audit" or "Enforce"
  
  # Policy suites
  baseline:
    enabled: true     # Enable 11 baseline policies
  restricted:
    enabled: true     # Enable 6 restricted policies
    
  # Kyverno settings
  background: true    # Enable background processing
  emitWarning: false  # Emit warnings for violations
  admission: true     # Enable admission control

# Namespace exclusions (system namespaces)
excludeNamespaces:
  - kube-system
  - kube-public
  - kube-node-lease
  - kyverno
  - argocd
```

### Production Configuration Example

```yaml
# values-prod.yaml
pss:
  validationFailureAction: "Enforce"  # Block violations in production
  
  baseline:
    enabled: true
    validationFailureAction: "Enforce"  # Override global for baseline
  
  restricted:
    enabled: true  
    validationFailureAction: "Audit"    # Still audit restricted for compatibility
    
  background: true
  emitWarning: true    # Show warnings for visibility
  admission: true

# Production exclusions
excludeNamespaces:
  - kube-system
  - kube-public
  - kube-node-lease
  - kyverno
  - argocd
  - istio-system
  - cert-manager
  - monitoring-system
```

### Development Configuration Example

```yaml
# values-dev.yaml
pss:
  validationFailureAction: "Audit"  # Only audit in development
  
  baseline:
    enabled: true
    validationFailureAction: "Audit"
  
  restricted:
    enabled: false  # Disable strict policies in dev
    
  background: false  # Reduce overhead in dev
  emitWarning: true
  admission: true
```

## 📦 Baseline Policies (11)

### 🚫 **Core Security Policies**

#### 1. **Disallow Privileged Containers** (`baseline/disallow-privileged-containers.yaml`)
```yaml
# Prevents privileged containers that have root access to host
spec:
  rules:
  - validate:
      message: "Privileged containers are not allowed"
      pattern:
        spec:
          =(securityContext):
            =(privileged): "false"
```

#### 2. **Disallow Capabilities** (`baseline/disallow-capabilities.yaml`)
```yaml  
# Restricts Linux capabilities that can be added
spec:
  rules:
  - validate:
      message: "Adding capabilities is not allowed"
      pattern:
        spec:
          =(securityContext):
            =(capabilities):
              X(add): null
```

#### 3. **Disallow Host Namespaces** (`baseline/disallow-host-namespaces.yaml`)
```yaml
# Prevents sharing host network, PID, or IPC namespaces
spec:
  rules:
  - validate:
      message: "Sharing the host namespaces is not allowed"
      pattern:
        spec:
          =(hostNetwork): "false"
          =(hostPID): "false"
          =(hostIPC): "false"
```

#### 4. **Disallow Host Ports** (`baseline/disallow-host-ports.yaml`)
```yaml
# Prevents binding to host ports
spec:
  rules:
  - validate:
      message: "Use of host ports is not allowed"
      pattern:
        spec:
          containers:
          - name: "*"
            =(ports):
            - X(hostPort): null
```

#### 5-11. **Additional Baseline Policies**
- **disallow-host-path**: Prevents host path volume mounts
- **disallow-host-process**: Restricts Windows host process containers  
- **disallow-se-linux-options**: Controls SELinux options
- **restrict-apparmor**: Restricts AppArmor profiles
- **restrict-seccomp**: Enforces seccomp profiles
- **restrict-sysctls**: Controls sysctl parameters
- **restrict-volume-types**: Limits allowed volume types

## 📦 Restricted Policies (6)

### 🔒 **Enhanced Security Policies**

#### 1. **Require Non-Root User** (`restricted/require-non-root-user.yaml`)
```yaml
# Ensures containers run as non-root user
spec:
  rules:
  - validate:
      message: "Containers must run as non-root user"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
```

#### 2. **Disallow Privilege Escalation** (`restricted/disallow-privilege-escalation.yaml`)
```yaml
# Prevents privilege escalation
spec:
  rules:
  - validate:
      message: "Privilege escalation is not allowed"
      pattern:
        spec:
          containers:
          - securityContext:
              allowPrivilegeEscalation: false
```

#### 3. **Require Seccomp Profile** (`restricted/require-seccomp-profile.yaml`)
```yaml  
# Mandates seccomp profile usage
spec:
  rules:
  - validate:
      message: "Seccomp profile is required"
      pattern:
        metadata:
          annotations:
            seccomp.security.alpha.kubernetes.io/pod: "runtime/default | localhost/*"
```

#### 4-6. **Additional Restricted Policies**
- **drop-all-capabilities**: Drops all Linux capabilities
- **restrict-volume-types**: Stricter volume type restrictions
- **restrict-running-user-id**: Enforces specific user ID ranges

## 🚀 Deployment

### Via ArgoCD (Recommended)
```yaml
# argocd-apps/kyverno-pss-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno-pss
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/anuddeeph1/musical-giggle.git
    targetRevision: gitops
    path: helm-charts/pss-policies
    helm:
      values: |
        pss:
          validationFailureAction: "Audit"  # Start with audit
          baseline:
            enabled: true
          restricted:
            enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: kyverno
```

### Direct Helm Deployment
```bash
# Install with audit mode (recommended first)
helm install kyverno-pss ./helm-charts/pss-policies \
  --namespace kyverno \
  --set pss.validationFailureAction=Audit

# Install with enforce mode
helm install kyverno-pss ./helm-charts/pss-policies \
  --namespace kyverno \
  --set pss.validationFailureAction=Enforce

# Production deployment
helm install kyverno-pss ./helm-charts/pss-policies \
  --namespace kyverno \
  --values values-prod.yaml
```

## 📊 Monitoring & Reporting

### Policy Reports
```bash
# View cluster-wide policy reports
kubectl get clusterpolicyreports

# View namespace-specific policy reports
kubectl get policyreports -A

# Check policy violations in specific namespace
kubectl describe policyreport -n devops-case-study
```

### Policy Status
```bash
# Check all PSS policies
kubectl get clusterpolicies -l app.kubernetes.io/name=pss-policies

# Verify policy readiness
kubectl get clusterpolicies -l app.kubernetes.io/name=pss-policies \
  -o custom-columns="NAME:.metadata.name,READY:.status.ready"

# View specific policy details
kubectl describe clusterpolicy disallow-privileged-containers
```

### Violation Analysis
```bash
# Count violations by policy
kubectl get policyreports -A -o json | \
  jq '.items[].results[] | select(.result=="fail") | .policy' | \
  sort | uniq -c

# Show recent violations
kubectl get events --field-selector reason=PolicyViolation \
  --sort-by='.metadata.creationTimestamp'
```

## 🔧 Troubleshooting

### Policy Not Applying
```bash
# Check policy deployment
kubectl get clusterpolicies -l app.kubernetes.io/name=pss-policies

# View Kyverno admission controller logs
kubectl logs -l app.kubernetes.io/name=kyverno-admission-controller \
  -n kyverno --tail=50

# Check for policy validation errors
kubectl describe clusterpolicy disallow-privileged-containers
```

### False Positives  
```bash
# Check namespace exclusions
kubectl get clusterpolicy disallow-privileged-containers \
  -o yaml | grep -A 10 exclude

# Verify pod labels and annotations
kubectl get pod <pod-name> -n <namespace> -o yaml | \
  head -20

# Review policy report details
kubectl describe policyreport <report-name> -n <namespace>
```

### Performance Issues
```bash
# Check admission webhook latency
kubectl get validatingadmissionwebhook kyverno-resource-validating-webhook-cfg \
  -o yaml | grep -A 5 admissionReviewVersions

# Monitor policy processing time
kubectl top pods -l app.kubernetes.io/name=kyverno-admission-controller -n kyverno

# Check background processing
kubectl logs -l app.kubernetes.io/name=kyverno-background-controller \
  -n kyverno --tail=30
```

## 🎯 Use Cases & Examples

### 🔍 **Audit Mode (Recommended Start)**
```yaml
# Start with audit to understand current violations
pss:
  validationFailureAction: "Audit"
  baseline:
    enabled: true
  restricted:
    enabled: false  # Start with baseline only
```

### ⚖️ **Gradual Enforcement**
```yaml
# Phase 1: Audit everything
validationFailureAction: "Audit"

# Phase 2: Enforce baseline, audit restricted
baseline:
  validationFailureAction: "Enforce"
restricted:
  validationFailureAction: "Audit"

# Phase 3: Enforce everything  
validationFailureAction: "Enforce"
```

### 🎯 **Namespace-Specific Configuration**
```yaml
# Different policies for different environments
excludeNamespaces:
  - kube-system      # System namespace
  - development      # Relaxed policies
  - legacy-apps      # Legacy applications
```

## 📋 Values Reference

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `pss.validationFailureAction` | Global action (Audit/Enforce) | `"Audit"` | No |
| `pss.baseline.enabled` | Enable baseline policies | `true` | No |
| `pss.baseline.validationFailureAction` | Baseline-specific action | Inherits global | No |
| `pss.restricted.enabled` | Enable restricted policies | `true` | No |
| `pss.restricted.validationFailureAction` | Restricted-specific action | Inherits global | No |
| `pss.background` | Enable background processing | `true` | No |
| `pss.emitWarning` | Emit warnings for violations | `false` | No |
| `pss.admission` | Enable admission control | `true` | No |
| `excludeNamespaces` | Namespaces to exclude | System namespaces | No |

## 📈 Migration Path

### From Manual NetworkPolicies
```bash
# 1. Deploy in audit mode first
helm install kyverno-pss ./helm-charts/pss-policies \
  --set pss.validationFailureAction=Audit

# 2. Review violations
kubectl get policyreports -A

# 3. Fix applications gradually  
kubectl describe policyreport <namespace-report>

# 4. Switch to enforce mode
helm upgrade kyverno-pss ./helm-charts/pss-policies \
  --set pss.validationFailureAction=Enforce
```

### Integration with CI/CD
```yaml
# Add to CI pipeline
steps:
- name: Validate PSS Compliance
  run: |
    helm template ./helm-charts/pss-policies | kubectl apply --dry-run=server -f -
```

## 🔗 Policy Templates

### Template Structure
```
helm-charts/pss-policies/templates/
├── baseline/                           # 11 Baseline policies
│   ├── disallow-privileged-containers.yaml
│   ├── disallow-capabilities.yaml
│   ├── disallow-host-namespaces.yaml
│   ├── disallow-host-ports.yaml
│   ├── disallow-host-path.yaml
│   ├── disallow-host-process.yaml
│   ├── disallow-se-linux-options.yaml
│   ├── restrict-apparmor.yaml
│   ├── restrict-seccomp.yaml
│   ├── restrict-sysctls.yaml
│   └── restrict-volume-types.yaml
└── restricted/                         # 6 Restricted policies  
    ├── require-non-root-user.yaml
    ├── disallow-privilege-escalation.yaml
    ├── require-seccomp-profile.yaml
    ├── drop-all-capabilities.yaml
    ├── restrict-volume-types.yaml
    └── restrict-running-user-id.yaml
```

## 🔗 Related Documentation

- [📋 Main Project README](../../README.md)
- [⚡ Kyverno Helm Chart](../kyverno/README.md)
- [🔒 Network Policies Helm Chart](../network-policies/README.md)
- [🌐 Web Server Helm Chart](../web-server/README.md)
- [💾 Database Helm Chart](../database/README.md)
- [📊 Monitoring Helm Chart](../monitoring/README.md)

---

**🛡️ Kubernetes Pod Security Standards with configurable enforcement!** 🚀