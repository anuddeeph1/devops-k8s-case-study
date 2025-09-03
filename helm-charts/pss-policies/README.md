# Pod Security Standards (PSS) Policies for Kyverno

This Helm chart deploys Kubernetes Pod Security Standards policies using Kyverno.

## Overview

This chart includes two sets of policies:
- **Baseline**: Essential security controls with minimal disruption
- **Restricted**: Stricter security requirements following security best practices

## Configuration

### Key Values

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `pss.validationFailureAction` | Policy enforcement mode | `"Audit"` | `"Audit"`, `"Enforce"` |
| `pss.baseline.enabled` | Enable baseline policies | `true` | `true`, `false` |
| `pss.restricted.enabled` | Enable restricted policies | `true` | `true`, `false` |
| `pss.background` | Background scanning for existing resources | `true` | `true`, `false` |
| `pss.admission` | Validate on create/update | `true` | `true`, `false` |
| `pss.emitWarning` | Emit warnings in addition to logging | `false` | `true`, `false` |

### Enforcement Modes

#### Audit Mode (Recommended for Testing)
```yaml
pss:
  validationFailureAction: "Audit"
```
- **Logs violations** but **allows workloads** to be created
- Ideal for **testing** and **understanding policy impact**
- **No disruption** to existing workloads

#### Enforce Mode (Production)
```yaml
pss:
  validationFailureAction: "Enforce"
```
- **Blocks non-compliant** workloads
- Use after **testing with Audit mode**
- Requires **workload compliance**

### Namespace Exclusions

System namespaces are excluded by default:
```yaml
excludeNamespaces:
  - kube-system
  - kube-public
  - kube-node-lease
  - kyverno
  - argocd
```

### Per-Policy Overrides

Override settings for specific policies:
```yaml
policies:
  disallow-privileged-containers:
    validationFailureAction: "Enforce"  # Enforce this specific policy
    background: false
  
  require-run-as-nonroot:
    validationFailureAction: "Audit"
```

## Usage Examples

### 1. Audit Mode (Safe Testing)
```yaml
pss:
  validationFailureAction: "Audit"
  baseline:
    enabled: true
  restricted:
    enabled: false  # Start with baseline only
```

### 2. Gradual Enforcement
```yaml
# Start with baseline enforcement, restricted audit
pss:
  validationFailureAction: "Audit"
  baseline:
    enabled: true
  restricted:
    enabled: true

# Override baseline to enforce
policies:
  disallow-privileged-containers:
    validationFailureAction: "Enforce"
  disallow-capabilities:
    validationFailureAction: "Enforce"
```

### 3. Full Enforcement (Production)
```yaml
pss:
  validationFailureAction: "Enforce"
  baseline:
    enabled: true
  restricted:
    enabled: true
  background: true  # Scan existing resources
```

## Policy Categories

### Baseline Policies
- `disallow-capabilities`: Restrict Linux capabilities
- `disallow-host-namespaces`: Prevent host namespace access
- `disallow-host-path`: Restrict host path mounts
- `disallow-host-ports`: Prevent host port usage
- `disallow-host-process`: Block host process containers
- `disallow-privileged-containers`: Block privileged containers
- `disallow-proc-mount`: Restrict /proc mount options
- `disallow-selinux`: Control SELinux options
- `restrict-apparmor-profiles`: Limit AppArmor profiles
- `restrict-seccomp`: Control seccomp profiles
- `restrict-sysctls`: Limit unsafe sysctls

### Restricted Policies
- `disallow-capabilities-strict`: Stricter capability restrictions
- `disallow-privilege-escalation`: Prevent privilege escalation
- `require-run-as-nonroot`: Require non-root user
- `require-run-as-non-root-user`: Require specific non-root user
- `restrict-seccomp-strict`: Stricter seccomp requirements
- `restrict-volume-types`: Limit volume types

## Installation

### Via ArgoCD
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pss-policies
spec:
  source:
    repoURL: https://github.com/anuddeeph1/musical-giggle.git
    path: helm-charts/pss-policies
    helm:
      values: |
        pss:
          validationFailureAction: "Audit"
```

### Via Helm CLI
```bash
helm install pss-policies ./helm-charts/pss-policies \
  --set pss.validationFailureAction=Audit
```

## Monitoring

Check policy reports:
```bash
# View policy violations
kubectl get policyreports -A

# View cluster-wide policy reports
kubectl get clusterpolicyreports

# Check specific policy status
kubectl get clusterpolicy
```

## Troubleshooting

### Common Issues

1. **Workloads blocked unexpectedly**
   - Switch to `validationFailureAction: "Audit"` 
   - Check policy reports for violations
   - Fix workload security issues

2. **Policies not applying**
   - Verify Kyverno is running: `kubectl get pods -n kyverno`
   - Check namespace exclusions
   - Review policy conditions

3. **Too many violations**
   - Start with baseline only
   - Use namespace exclusions
   - Gradually enable restricted policies

### Debug Commands

```bash
# Check Kyverno status
kubectl get pods -n kyverno

# View policy status
kubectl get clusterpolicy

# Check policy reports
kubectl get policyreports -A

# View specific policy details
kubectl describe clusterpolicy <policy-name>
```
