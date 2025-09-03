# 🔒 Network Policies Helm Chart

> **Zero-trust networking with automated NetworkPolicy generation via Kyverno Policy-as-Code**

## 📋 Overview

The **network-policies** chart deploys intelligent NetworkPolicy generators using Kyverno that:
- **Auto-generate NetworkPolicies** based on pod and namespace labels
- **Implement zero-trust networking** with default-deny-all approach
- **Support existing infrastructure** with `generateExisting: true`
- **Provide comprehensive security** for all microservice communications
- **Enable policy-as-code** with GitOps integration

## 🏗️ Architecture

```
🛡️ Zero-Trust Network Architecture

┌─────────────────────────────────────────────────────────────────┐
│                     devops-case-study Namespace                 │
│                                                                 │
│  🚫 default-deny-all (blocks ALL traffic by default)            |
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ Load Tester │────│ Web Server  │────│  Database   │         │
│  │    🔄       │ ✅ │     🌐       │ ✅ │    💾       │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                   │                   │              │
│         │              ┌─────────────┐          │              │
│         └──────────────│ Monitoring  │──────────┘              │
│                   ✅   │     📊     │     ✅                    │
│                        └─────────────┘                          │
│                                                                 │
│  🌐 allow-dns (DNS resolution for all pods)                     │
│  📡 allow-web-server-ingress (external access)                  │
└─────────────────────────────────────────────────────────────────┘

🔧 Kyverno ClusterPolicies (Auto-Generate NetworkPolicies):
├── 📋 generate-default-deny-all-networkpolicy      (namespace-triggered)
├── 🌐 generate-allow-dns-networkpolicy             (namespace-triggered)  
├── 💾 generate-allow-web-to-database-networkpolicy (pod-triggered)
├── 📊 generate-allow-monitoring-*-networkpolicy    (pod-triggered)
├── 🔄 generate-allow-load-testing-*-networkpolicy  (pod-triggered)
└── 📡 generate-allow-web-server-*-networkpolicy    (pod-triggered)
```

## ✨ Key Features

### 🤖 **Automated Policy Generation**
- **Event-driven**: Policies trigger on pod/namespace creation
- **Label-based**: Uses `app.kubernetes.io/name` labels for targeting
- **Background processing**: Scans existing resources every 1 minute
- **Zero-touch security**: No manual NetworkPolicy management

### 🔐 **Zero-Trust Implementation**
- **Default deny all**: Blocks all traffic by default
- **Principle of least privilege**: Only necessary connections allowed
- **Explicit allow lists**: Every connection must be authorized
- **Comprehensive coverage**: All microservice interactions secured

### ⚡ **Production-Ready Features**
- **Existing resource support**: `generateExisting: true` for live environments
- **GitOps integration**: Full ArgoCD deployment support
- **Audit mode**: Start with monitoring before enforcement
- **Performance optimized**: Background scanning with configurable intervals

## 🔧 Configuration

### Default Values (`values.yaml`)

```yaml
# Network policy configuration
networkPolicies:
  enabled: true
  targetNamespace: "devops-case-study"

# Kyverno policy configuration
kyverno:
  # Background processing
  background: true
  # Policy validation failure action
  validationFailureAction: "audit"
  # Generate policy settings - ENABLED for existing resources!
  generateExisting: true

# Pod labels for targeting (must match microservice labels)
podLabels:
  database: "database"
  webServer: "web-server"
  monitoring: "monitoring"
  loadTesting: "load-testing"

# Namespace exclusions (where policies should NOT apply)
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
networkPolicies:
  enabled: true
  targetNamespace: "production"

kyverno:
  background: true
  validationFailureAction: "Enforce"  # Enforce policies in production
  generateExisting: true

# Production pod labels
podLabels:
  database: "postgres"
  webServer: "frontend"
  monitoring: "prometheus"
  loadTesting: "k6"

# Additional exclusions
excludeNamespaces:
  - kube-system
  - kube-public
  - kube-node-lease
  - kyverno
  - argocd
  - istio-system
  - cert-manager
```

## 📦 Generated NetworkPolicies

### 🚫 **Namespace-Triggered Policies** (2)

#### 1. **default-deny-all** (`templates/default-deny-all.yaml`)
```yaml
# 🚫 Blocks ALL ingress and egress traffic by default
# Triggers: Namespace creation with name matching targetNamespace
spec:
  podSelector: {}          # Applies to ALL pods
  policyTypes:
    - Ingress             # Block all incoming traffic
    - Egress              # Block all outgoing traffic
```

#### 2. **allow-dns** (`templates/allow-dns.yaml`)
```yaml
# 🌐 Allows DNS resolution for all pods
# Triggers: Namespace creation with name matching targetNamespace  
spec:
  podSelector: {}          # Applies to ALL pods
  policyTypes: [Egress]
  egress:
  - to: []                 # Allow to any destination
    ports:
    - protocol: UDP
      port: 53             # DNS port
    - protocol: TCP  
      port: 53             # DNS over TCP
```

### 🎯 **Pod-Triggered Policies** (8)

#### 1. **allow-web-to-database** (`templates/allow-web-to-database.yaml`)
```yaml
# 💾 Web server access to database on port 3306
# Triggers: Pod creation with app.kubernetes.io/name=database
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: database
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: web-server
    ports: [{protocol: TCP, port: 3306}]
```

#### 2. **allow-web-server-ingress** (`templates/allow-web-server-ingress.yaml`)  
```yaml
# 📡 External access to web server on port 8080
# Triggers: Pod creation with app.kubernetes.io/name=web-server
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: web-server
  ingress:
  - from: []  # Allow from anywhere (external access)
    ports: [{protocol: TCP, port: 8080}]
```

#### 3. **allow-web-server-egress** (`templates/allow-web-server-egress.yaml`)
```yaml
# 🌐 Web server egress to database
# Triggers: Pod creation with app.kubernetes.io/name=web-server
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: web-server
  egress:
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: database
    ports: [{protocol: TCP, port: 3306}]
```

#### 4-8. **Additional Policies**
- **allow-monitoring-access**: Monitoring → All services
- **allow-monitoring-ingress**: Web Server → Monitoring  
- **allow-load-testing-access**: Load Tester → Web Server
- **allow-web-server-load-testing**: Web Server ← Load Tester
- **allow-database-monitoring**: Database → Monitoring

## 🚀 Deployment

### Via ArgoCD (Recommended)
```yaml
# argocd-apps/network-policies-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: network-policies
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/anuddeeph1/musical-giggle.git
    targetRevision: gitops
    path: helm-charts/network-policies
    helm:
      values: |
        kyverno:
          generateExisting: true  # 🚀 CRITICAL for existing resources
  destination:
    server: https://kubernetes.default.svc
    namespace: kyverno  # ClusterPolicies deploy to kyverno namespace
```

### Direct Helm Deployment
```bash
# Install network policies
helm install network-policies ./helm-charts/network-policies \
  --namespace kyverno \
  --create-namespace

# Install with existing resources support
helm install network-policies ./helm-charts/network-policies \
  --namespace kyverno \
  --set kyverno.generateExisting=true

# Production deployment
helm install network-policies ./helm-charts/network-policies \
  --namespace kyverno \
  --values values-prod.yaml
```

## 📊 Operations & Monitoring

### Verify ClusterPolicies Deployment
```bash
# Check all network policy generators
kubectl get clusterpolicies -l app.kubernetes.io/name=network-policies

# Verify policies are Ready
kubectl get clusterpolicies -l app.kubernetes.io/name=network-policies \
  -o custom-columns="NAME:.metadata.name,READY:.status.ready"

# Check specific policy details
kubectl describe clusterpolicy generate-default-deny-all-networkpolicy
```

### Monitor NetworkPolicy Generation
```bash
# List auto-generated NetworkPolicies
kubectl get networkpolicies -n devops-case-study

# Check NetworkPolicy details
kubectl describe networkpolicy default-deny-all -n devops-case-study

# View NetworkPolicy in YAML
kubectl get networkpolicy allow-web-to-database -n devops-case-study -o yaml
```

### Test Network Security
```bash
# Test denied connections (should fail)
kubectl exec -it deployment/mysql -n devops-case-study -- \
  nc -zv web-server 22  # Should be blocked

# Test allowed connections (should succeed)  
kubectl exec -it deployment/web-server -n devops-case-study -- \
  nc -zv mysql 3306     # Should be allowed
```

## 🔧 Policy Triggers & Behavior

### 🎯 **Pod-Triggered Policies**
```yaml
# Trigger Conditions:
match:
  any:
  - resources:
      kinds: [Pod]
      namespaces: [devops-case-study]
      
preconditions:
  all:
  - key: "{{ request.object.metadata.labels.\"app.kubernetes.io/name\" || '' }}"
    operator: Equals
    value: "database"  # Specific to each policy

# Behavior:
- Triggers when pod with matching label is created/updated
- Generates NetworkPolicy in same namespace as triggering pod  
- Uses generateExisting: true for existing pods
- Background scanning every 1 minute via BACKGROUND_SCAN_INTERVAL
```

### 🏢 **Namespace-Triggered Policies**  
```yaml
# Trigger Conditions:
match:
  any:
  - resources:
      kinds: [Namespace]
      names: [devops-case-study]

# Behavior:
- Triggers when target namespace is created
- Generates NetworkPolicy immediately in target namespace
- Uses generateExisting: true for existing namespaces
- Creates foundational security (deny-all, allow-dns)
```

## 🔧 Troubleshooting

### NetworkPolicies Not Generated
```bash
# Check ClusterPolicy status
kubectl get clusterpolicies -l app.kubernetes.io/name=network-policies \
  -o yaml | grep -A 5 status

# Verify Kyverno background controller is running
kubectl get pods -l app.kubernetes.io/name=kyverno-background-controller \
  -n kyverno

# Check Kyverno background controller logs
kubectl logs -l app.kubernetes.io/name=kyverno-background-controller \
  -n kyverno --tail=50
```

### Policy Validation Errors
```bash
# Check policy reports for violations
kubectl get policyreports -A

# View specific policy report
kubectl describe policyreport <report-name> -n devops-case-study

# Check admission webhook logs
kubectl logs -l app.kubernetes.io/name=kyverno-admission-controller \
  -n kyverno --tail=50
```

### Network Connectivity Issues  
```bash
# Test basic pod connectivity
kubectl exec -it deployment/web-server -n devops-case-study -- \
  ping mysql.devops-case-study.svc.cluster.local

# Check if NetworkPolicy is blocking traffic
kubectl get networkpolicies -n devops-case-study -o yaml

# View NetworkPolicy logs (via CNI if available)
kubectl describe pod <failing-pod> -n devops-case-study
```

### Background Processing Issues
```bash
# Check background scan interval
kubectl get deployment kyverno-background-controller -n kyverno \
  -o jsonpath='{.spec.template.spec.containers[0].env[*]}'

# Verify generateExisting setting
kubectl get clusterpolicy generate-default-deny-all-networkpolicy \
  -o jsonpath='{.spec.rules[0].generate.generateExisting}'

# Force manual policy re-evaluation
kubectl annotate clusterpolicy generate-default-deny-all-networkpolicy \
  kyverno.io/force-apply="$(date +%s)"
```

## 🎯 Advanced Scenarios

### Custom Pod Labels
```yaml
# For applications with different labels:
podLabels:
  frontend: "react-app"
  backend: "node-api"  
  cache: "redis"
  queue: "rabbitmq"
```

### Multi-Environment Support
```bash
# Development environment
helm install network-policies ./helm-charts/network-policies \
  --namespace kyverno \
  --set networkPolicies.targetNamespace=development

# Staging environment  
helm install network-policies ./helm-charts/network-policies \
  --namespace kyverno \
  --set networkPolicies.targetNamespace=staging
```

### Enforcement Mode
```yaml
# Switch from Audit to Enforce
kyverno:
  validationFailureAction: "Enforce"  # Block violating resources
```

## 📋 Values Reference

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `networkPolicies.enabled` | Enable NetworkPolicy generation | `true` | No |
| `networkPolicies.targetNamespace` | Target namespace for policies | `devops-case-study` | Yes |
| `kyverno.background` | Enable background processing | `true` | No |
| `kyverno.validationFailureAction` | Policy action (Audit/Enforce) | `audit` | No |
| `kyverno.generateExisting` | Generate for existing resources | `true` | No |
| `podLabels.database` | Database pod label value | `database` | Yes |
| `podLabels.webServer` | Web server pod label value | `web-server` | Yes |
| `podLabels.monitoring` | Monitoring pod label value | `monitoring` | Yes |
| `podLabels.loadTesting` | Load testing pod label value | `load-testing` | Yes |
| `excludeNamespaces` | Namespaces to exclude from policies | `[kube-system, ...]` | No |

## 🔗 Policy Templates

### Template Structure
```
helm-charts/network-policies/templates/
├── default-deny-all.yaml          # 🚫 Block all traffic (namespace)
├── allow-dns.yaml                 # 🌐 Allow DNS resolution (namespace)
├── allow-web-to-database.yaml     # 💾 Web → DB access (pod)
├── allow-web-server-ingress.yaml  # 📡 External → Web access (pod)
├── allow-web-server-egress.yaml   # 🌐 Web → DB egress (pod)
├── allow-monitoring-access.yaml   # 📊 Monitoring → All (pod)
├── allow-monitoring-ingress.yaml  # 📈 Web → Monitoring (pod)
├── allow-load-testing-access.yaml # 🔄 Load test → Web (pod)
├── allow-web-server-load-testing.yaml # ⚖️ Web ← Load test (pod)
└── allow-database-monitoring.yaml # 💾 DB → Monitoring (pod)
```

## 🔗 Related Documentation

- [📋 Main Project README](../../README.md)
- [⚡ Kyverno Helm Chart](../kyverno/README.md)
- [🛡️ PSS Policies Helm Chart](../pss-policies/README.md)
- [🌐 Web Server Helm Chart](../web-server/README.md)
- [💾 Database Helm Chart](../database/README.md)
- [📊 Monitoring Helm Chart](../monitoring/README.md)

---

**🔒 Zero-trust networking with automated NetworkPolicy generation!** 🚀
