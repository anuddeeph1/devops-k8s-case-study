# 🌐 Web Server Helm Chart

> **Frontend microservice with horizontal pod autoscaling and comprehensive monitoring**

## 📋 Overview

The **web-server** chart deploys a production-ready Node.js application with:
- **Horizontal Pod Autoscaler** (HPA) for automatic scaling
- **Comprehensive health checks** (liveness & readiness probes)
- **Network security** integration with auto-generated NetworkPolicies
- **Resource optimization** with requests and limits
- **Ingress configuration** for external access

## 🏗️ Architecture

```
┌───────────────── ┐    ┌─────────────────┐    ┌─────────────────┐
│    Ingress       │────│  Web Server     │────│    Database     │
│ (External Access)│    │  (2-10 replicas)│    │     (MySQL)     │
└───────────────── ┘    └─────────────────┘    └─────────────────┘
                                │
                                │
                       ┌─────────────────┐
                       │       HPA       │
                       │ (CPU-based      │
                       │  scaling)       │
                       └─────────────────┘
```

## 🔧 Configuration

### Default Values (`values.yaml`)

```yaml
# Replica configuration
replicaCount: 2
maxReplicas: 10

# Container configuration  
image:
  repository: nginx
  tag: "latest"
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 8080

# HPA configuration
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Resource management
resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 250m
    memory: 128Mi
```

### Customization Examples

#### Production Configuration
```yaml
# values-prod.yaml
replicaCount: 5
maxReplicas: 20

image:
  repository: your-registry/web-app
  tag: "v2.1.0"

resources:
  limits:
    cpu: 1000m
    memory: 512Mi
  requests:
    cpu: 500m
    memory: 256Mi

autoscaling:
  targetCPUUtilizationPercentage: 60
```

#### Development Configuration
```yaml
# values-dev.yaml
replicaCount: 1
autoscaling:
  enabled: false

resources:
  limits:
    cpu: 200m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 64Mi
```

## 📦 Components

### 🚀 **Deployment** (`templates/deployment.yaml`)
- **Multi-replica** configuration with HPA support
- **Health probes** for reliability
- **Resource limits** for stability
- **Security context** with non-root user
- **ConfigMap integration** for application configuration

### 🔧 **Service** (`templates/service.yaml`)
- **ClusterIP service** for internal communication
- **Port mapping** (80 → 8080)
- **Label selectors** for NetworkPolicy automation

### ⚖️ **HPA** (`templates/hpa.yaml`)
- **CPU-based scaling** (default 70% threshold)
- **Configurable replica range** (2-10 by default)
- **Automatic scale-up/down** based on load

### 🌍 **Ingress** (`templates/ingress.yaml`)
- **External access** configuration
- **Host-based routing** support
- **TLS termination** ready

### 📋 **ConfigMap** (`templates/configmap.yaml`)
- **Application configuration** management
- **Environment-specific** settings
- **Runtime reconfiguration** support

## 🔐 Security Integration

### NetworkPolicy Auto-Generation
The web-server automatically gets secured with NetworkPolicies:

```yaml
# Auto-generated based on app.kubernetes.io/name=web-server label
- allow-web-server-ingress    # External access on port 8080
- allow-web-server-egress     # Database access on port 3306
- allow-monitoring-ingress    # Monitoring access from monitoring pods
- allow-web-server-load-testing # Load testing access
```

### Pod Security Standards
Complies with **Restricted** Pod Security Standards:
- ✅ **Non-root user** execution
- ✅ **Read-only root filesystem** 
- ✅ **Security capabilities** dropped
- ✅ **Privilege escalation** prevented

## 📊 Monitoring

### Health Checks
```yaml
# Liveness Probe
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

# Readiness Probe  
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Metrics Endpoints
- **Health**: `GET /health` - Application health status
- **Ready**: `GET /ready` - Service readiness status
- **Metrics**: `GET /metrics` - Prometheus-style metrics

## 🚀 Deployment

### Via ArgoCD (Recommended)
```yaml
# argocd-apps/web-server-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-server
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/anuddeeph1/musical-giggle.git
    targetRevision: gitops
    path: helm-charts/web-server
```

### Direct Helm Deployment
```bash
# Install
helm install web-server ./helm-charts/web-server \
  --namespace devops-case-study \
  --create-namespace

# Upgrade
helm upgrade web-server ./helm-charts/web-server \
  --namespace devops-case-study

# Uninstall
helm uninstall web-server --namespace devops-case-study
```

### With Custom Values
```bash
# Production deployment
helm install web-server ./helm-charts/web-server \
  --namespace devops-case-study \
  --values values-prod.yaml

# Development deployment
helm install web-server ./helm-charts/web-server \
  --namespace devops-case-study \
  --values values-dev.yaml
```

## 📈 Scaling Operations

### Manual Scaling
```bash
# Scale to specific replica count
kubectl scale deployment web-server --replicas=5 -n devops-case-study

# Check current scaling
kubectl get deployment web-server -n devops-case-study
```

### HPA Monitoring
```bash
# View HPA status
kubectl get hpa web-server-hpa -n devops-case-study

# Detailed HPA information
kubectl describe hpa web-server-hpa -n devops-case-study

# Watch HPA in real-time
kubectl get hpa web-server-hpa -n devops-case-study -w
```

### Load Testing
```bash
# Trigger load test to see HPA in action
kubectl create job --from=cronjob/load-test-cronjob \
  load-test-manual-$(date +%s) -n devops-case-study

# Monitor scaling during load test
watch kubectl get pods -n devops-case-study
```

## 🔧 Troubleshooting

### Common Issues

#### Pod Not Starting
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=web-server -n devops-case-study

# View pod logs
kubectl logs deployment/web-server -n devops-case-study

# Describe pod for events
kubectl describe pod <pod-name> -n devops-case-study
```

#### HPA Not Scaling
```bash
# Check HPA status
kubectl describe hpa web-server-hpa -n devops-case-study

# Verify metrics server
kubectl get apiservice v1beta1.metrics.k8s.io

# Check resource requests are set
kubectl get deployment web-server -o yaml | grep -A 5 resources
```

#### Network Connectivity Issues
```bash
# Check service endpoints
kubectl get endpoints web-server -n devops-case-study

# Test service connectivity
kubectl run test-pod --image=curlimages/curl -it --rm -- \
  curl http://web-server.devops-case-study.svc.cluster.local

# Check NetworkPolicies
kubectl get networkpolicies -n devops-case-study
```

## 📋 Values Reference

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `replicaCount` | Number of replicas to deploy | `2` | No |
| `image.repository` | Container image repository | `nginx` | Yes |
| `image.tag` | Container image tag | `latest` | No |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` | No |
| `service.type` | Kubernetes service type | `ClusterIP` | No |
| `service.port` | Service port | `80` | No |
| `service.targetPort` | Target port on container | `8080` | No |
| `autoscaling.enabled` | Enable HPA | `true` | No |
| `autoscaling.minReplicas` | Minimum replicas for HPA | `2` | No |
| `autoscaling.maxReplicas` | Maximum replicas for HPA | `10` | No |
| `autoscaling.targetCPUUtilizationPercentage` | CPU target for HPA | `70` | No |
| `resources.limits.cpu` | CPU limit | `500m` | No |
| `resources.limits.memory` | Memory limit | `256Mi` | No |
| `resources.requests.cpu` | CPU request | `250m` | No |
| `resources.requests.memory` | Memory request | `128Mi` | No |
| `ingress.enabled` | Enable ingress | `true` | No |
| `ingress.className` | Ingress class name | `nginx` | No |
| `ingress.host` | Ingress host | `web-server.local` | No |

## 🔗 Related Documentation

- [📋 Main Project README](../../README.md)
- [💾 Database Helm Chart](../database/README.md) 
- [📊 Monitoring Helm Chart](../monitoring/README.md)
- [🔄 Load Testing Helm Chart](../load-testing/README.md)
- [🛡️ Security Policies](../network-policies/README.md)

---

**🌐 Frontend microservice ready for production!** 🚀
