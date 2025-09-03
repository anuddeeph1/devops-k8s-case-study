# 📊 Monitoring Helm Chart

> **Custom Prometheus-style monitoring service with comprehensive RBAC and network security integration**

## 📋 Overview

The **monitoring** chart deploys a lightweight monitoring solution with:
- **Custom metrics collection** from all microservices
- **RBAC integration** with proper service account permissions
- **Network policy compliance** for secure metrics access
- **Pod discovery** across the cluster
- **Resource optimization** for efficient monitoring

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Server    │────│   Monitoring    │────│    Database     │
│ /metrics        │    │   (Scraper)     │    │ /metrics        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                │
                       ┌─────────────────┐
                       │  Load Tester    │
                       │ /metrics        │
                       └─────────────────┘

         🔐 RBAC Permissions
    ┌─────────────────────────────┐
    │ • pods (list, get)          │
    │ • services (list, get)      │  
    │ • endpoints (list, get)     │
    │ • configmaps (list, get)    │
    └─────────────────────────────┘
```

## 🔧 Configuration

### Default Values (`values.yaml`)

```yaml
# Replica configuration
replicaCount: 1

# Container configuration
image:
  repository: prom/prometheus
  tag: "latest"
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: ClusterIP
  port: 9090
  targetPort: 9090

# RBAC configuration
serviceAccount:
  create: true
  name: "pod-monitor"

# Resource management
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Monitoring configuration
monitoring:
  scrapeInterval: 30s
  evaluationInterval: 30s
  retentionTime: 15d
```

### Production Configuration Example

```yaml
# values-prod.yaml
replicaCount: 2  # High availability

image:
  repository: prom/prometheus
  tag: "v2.45.0"  # Pinned version

resources:
  limits:
    cpu: 1000m
    memory: 2048Mi
  requests:
    cpu: 500m
    memory: 1024Mi

# Production monitoring settings
monitoring:
  scrapeInterval: 15s      # More frequent scraping
  evaluationInterval: 15s  # Faster alerting
  retentionTime: 90d       # Longer retention
  
# Persistence for metrics
persistence:
  enabled: true
  size: 50Gi
  storageClass: "fast-ssd"
```

## 📦 Components

### 🚀 **Deployment** (`templates/deployment.yaml`)
- **Single replica** monitoring instance (configurable)
- **Custom Prometheus** configuration for microservices
- **Service account** with RBAC permissions
- **Health probes** for reliability
- **Resource limits** for stability

### 🔑 **ServiceAccount** (`templates/serviceaccount.yaml`)
```yaml
# Dedicated service account: pod-monitor
metadata:
  name: pod-monitor
  labels:
    app.kubernetes.io/name: monitoring
```

### 🛡️ **RBAC** (`templates/rbac.yaml`)
```yaml
# ClusterRole permissions for monitoring:
- pods: [list, get]        # Pod discovery
- services: [list, get]    # Service discovery  
- endpoints: [list, get]   # Endpoint monitoring
- configmaps: [list, get]  # Configuration access
```

### 🔧 **Service** (`templates/service.yaml`)
- **ClusterIP service** on port 9090
- **Internal access** for metrics collection
- **NetworkPolicy integration** for security
- **DNS resolution**: `monitoring.devops-case-study.svc.cluster.local:9090`

### 📋 **ConfigMap** (`templates/configmap.yaml`)
```yaml
# Prometheus configuration for microservices:
scrape_configs:
  - job_name: 'web-server'
    static_configs:
      - targets: ['web-server:8080']
  - job_name: 'database' 
    static_configs:
      - targets: ['mysql:3306']
  - job_name: 'monitoring'
    static_configs:
      - targets: ['monitoring:9090']
```

## 🔐 Security Integration

### NetworkPolicy Auto-Generation
The monitoring service gets secured with NetworkPolicies:

```yaml
# Auto-generated based on app.kubernetes.io/name=monitoring label
- allow-monitoring-access     # Access FROM monitoring TO all services
- allow-monitoring-ingress    # Access TO monitoring FROM web-server
- default-deny-all           # Blocks all other traffic
```

### RBAC Security
- **Principle of least privilege** with minimal required permissions
- **Namespace-scoped** access where possible
- **Service account binding** for pod identity
- **No privileged** container execution

### Pod Security Standards
Complies with **Restricted** Pod Security Standards:
- ✅ **Non-root user** execution
- ✅ **Read-only root filesystem**
- ✅ **Security capabilities** dropped
- ✅ **Privilege escalation** prevented

## 📊 Monitoring Capabilities

### Metrics Collection
```bash
# Available metrics endpoints:
Web Server:   GET http://web-server:8080/metrics
Database:     GET http://mysql:3306/metrics
Monitoring:   GET http://monitoring:9090/metrics
Load Tester:  GET http://load-tester:8080/metrics
```

### Service Discovery
```yaml
# Automatic service discovery configuration:
kubernetes_sd_configs:
  - role: pod
    namespaces:
      names: ['devops-case-study']
    selectors:
      - role: "pod"
        label: "app.kubernetes.io/name"
```

### Health Monitoring
```yaml
# Health check endpoints:
livenessProbe:
  httpGet:
    path: /-/healthy
    port: 9090
    
readinessProbe:
  httpGet:
    path: /-/ready
    port: 9090
```

## 🚀 Deployment

### Via ArgoCD (Recommended)
```yaml
# argocd-apps/monitoring-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/anuddeeph1/musical-giggle.git
    targetRevision: gitops
    path: helm-charts/monitoring
  destination:
    server: https://kubernetes.default.svc
    namespace: devops-case-study
```

### Direct Helm Deployment
```bash
# Install monitoring
helm install monitoring ./helm-charts/monitoring \
  --namespace devops-case-study \
  --create-namespace

# Upgrade monitoring
helm upgrade monitoring ./helm-charts/monitoring \
  --namespace devops-case-study

# Install with custom values
helm install monitoring ./helm-charts/monitoring \
  --namespace devops-case-study \
  --values values-prod.yaml
```

## 📈 Operations

### Accessing Monitoring Dashboard
```bash
# Port forward to access monitoring UI
kubectl port-forward service/monitoring 9090:9090 -n devops-case-study

# Access via browser
open http://localhost:9090
```

### Checking Metrics Collection
```bash
# Test metrics endpoints
kubectl exec -it deployment/monitoring -n devops-case-study -- \
  curl http://web-server:8080/metrics

# Check service discovery
kubectl exec -it deployment/monitoring -n devops-case-study -- \
  curl http://localhost:9090/api/v1/targets
```

### RBAC Verification
```bash
# Check service account
kubectl get serviceaccount pod-monitor -n devops-case-study

# Verify RBAC permissions
kubectl auth can-i list pods --as=system:serviceaccount:devops-case-study:pod-monitor

# Check role bindings
kubectl get clusterrolebinding -o wide | grep pod-monitor
```

## 🔧 Troubleshooting

### Common Issues

#### Metrics Not Being Scraped
```bash
# Check monitoring pod logs
kubectl logs deployment/monitoring -n devops-case-study

# Verify target endpoints
kubectl get endpoints -n devops-case-study

# Test service connectivity
kubectl exec -it deployment/monitoring -n devops-case-study -- \
  curl http://web-server:8080/health
```

#### RBAC Permission Errors
```bash
# Check service account
kubectl describe serviceaccount pod-monitor -n devops-case-study

# Verify cluster role
kubectl describe clusterrole pod-monitor-role

# Check role binding
kubectl describe clusterrolebinding pod-monitor-binding
```

#### Network Policy Blocks
```bash
# Check NetworkPolicies
kubectl get networkpolicies -n devops-case-study

# Describe specific network policy
kubectl describe networkpolicy allow-monitoring-access -n devops-case-study

# Test network connectivity
kubectl exec -it deployment/web-server -n devops-case-study -- \
  curl http://monitoring:9090/-/healthy
```

### Debug Commands

#### Service Discovery Debug
```bash
# Check Prometheus configuration
kubectl get configmap monitoring-config -n devops-case-study -o yaml

# View active targets in Prometheus
kubectl exec -it deployment/monitoring -n devops-case-study -- \
  curl http://localhost:9090/api/v1/targets
```

#### Pod Label Verification
```bash
# Check pod labels for monitoring
kubectl get pods -n devops-case-study --show-labels

# Verify monitoring can discover pods
kubectl exec -it deployment/monitoring -n devops-case-study -- \
  curl http://localhost:9090/api/v1/label/app_kubernetes_io_name/values
```

## 📊 Monitoring Queries

### Useful Prometheus Queries
```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by pod  
container_memory_usage_bytes

# HTTP request rate
rate(http_requests_total[5m])

# Database connections
mysql_global_status_threads_connected

# Pod restart count
increase(kube_pod_container_status_restarts_total[1h])
```

### Health Check Queries
```promql
# Service availability
up{job="web-server"}

# High CPU usage alert
rate(container_cpu_usage_seconds_total[5m]) > 0.8

# High memory usage alert
container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
```

## 📋 Values Reference

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `replicaCount` | Number of monitoring replicas | `1` | No |
| `image.repository` | Container image repository | `prom/prometheus` | Yes |
| `image.tag` | Container image tag | `latest` | No |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` | No |
| `service.type` | Service type | `ClusterIP` | No |
| `service.port` | Service port | `9090` | No |
| `service.targetPort` | Target port on container | `9090` | No |
| `serviceAccount.create` | Create service account | `true` | No |
| `serviceAccount.name` | Service account name | `pod-monitor` | No |
| `resources.limits.cpu` | CPU limit | `500m` | No |
| `resources.limits.memory` | Memory limit | `512Mi` | No |
| `resources.requests.cpu` | CPU request | `250m` | No |
| `resources.requests.memory` | Memory request | `256Mi` | No |
| `monitoring.scrapeInterval` | Metrics scrape interval | `30s` | No |
| `monitoring.evaluationInterval` | Rule evaluation interval | `30s` | No |
| `monitoring.retentionTime` | Data retention period | `15d` | No |

## 🔗 Integration Examples

### Custom Application Metrics
```yaml
# Add to your application deployment:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
```

### Alert Manager Integration
```yaml
# Add AlertManager configuration:
alertmanager:
  enabled: true
  config:
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://alertmanager-webhook:8080/webhook'
```

## 🔗 Related Documentation

- [📋 Main Project README](../../README.md)
- [🌐 Web Server Helm Chart](../web-server/README.md)
- [💾 Database Helm Chart](../database/README.md)
- [🔄 Load Testing Helm Chart](../load-testing/README.md)
- [🛡️ Network Policies](../network-policies/README.md)

---

**📊 Comprehensive monitoring for production microservices!** 🚀
