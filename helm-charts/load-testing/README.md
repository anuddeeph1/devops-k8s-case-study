# 🔄 Load Testing Helm Chart

> **High-performance load generator for HPA demonstration and performance validation**

## 📋 Overview

The **load-testing** chart deploys a powerful load testing solution with:
- **Configurable concurrent users** for scalable load generation
- **HPA trigger capability** to demonstrate auto-scaling
- **Comprehensive metrics** collection during tests
- **Network policy integration** for secure testing
- **CronJob scheduling** for automated performance testing
- **Resource optimization** for high-throughput testing

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Load Tester    │────│   Web Server    │────│    Database     │
│ (Configurable   │    │   (Target)      │    │   (Backend)     │
│  Concurrency)   │    │  HPA: 2-10      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └──────────────│   Monitoring    │──────────────┘
                        │   (Metrics)     │
                        └─────────────────┘

🔄 HPA Scaling Demonstration:
Load Test Start → CPU Spike → HPA Triggers → Pods Scale Up → Load Distributed
```

## 🔧 Configuration

### Default Values (`values.yaml`)

```yaml
# Load testing configuration
loadTest:
  # Target configuration
  targetUrl: "http://web-server:8080"
  targetPath: "/health"
  
  # Load parameters
  concurrentUsers: 50      # Number of concurrent users
  duration: "300s"         # Test duration (5 minutes)
  requestRate: 10          # Requests per second per user
  
  # Scheduling
  schedule: "0 */2 * * *"  # Every 2 hours
  enabled: true            # Enable CronJob

# Container configuration
image:
  repository: williamyeh/wrk
  tag: "latest"
  pullPolicy: IfNotPresent

# Resource management
resources:
  limits:
    cpu: 1000m      # High CPU for load generation
    memory: 512Mi
  requests:
    cpu: 500m
    memory: 256Mi

# Service configuration (for metrics)
service:
  type: ClusterIP
  port: 8080
  targetPort: 8080
```

### High-Load Configuration Example

```yaml
# values-high-load.yaml
loadTest:
  concurrentUsers: 100     # Higher concurrency
  duration: "600s"         # 10-minute tests
  requestRate: 20          # More requests per second
  schedule: "0 */1 * * *"  # Every hour
  
  # Advanced load patterns
  rampUp: "60s"           # Gradual load increase
  steadyState: "480s"     # Steady load period
  rampDown: "60s"         # Gradual load decrease

resources:
  limits:
    cpu: 2000m            # More CPU for higher load
    memory: 1024Mi
  requests:
    cpu: 1000m
    memory: 512Mi
```

### HPA Demo Configuration

```yaml
# values-hpa-demo.yaml
loadTest:
  concurrentUsers: 200     # High load to trigger HPA
  duration: "180s"         # Short burst for demo
  requestRate: 50          # High request rate
  schedule: "*/5 * * * *"  # Every 5 minutes for demo
  
  # HPA-specific settings
  targetUrl: "http://web-server:8080"
  targetPath: "/cpu-intensive"  # CPU-heavy endpoint
```

## 📦 Components

### ⏰ **CronJob** (`templates/cronjob.yaml`)
- **Scheduled execution** with configurable frequency
- **Parallel job** policy for concurrent tests
- **Success/failure** history retention
- **Resource limits** for stable execution
- **ConfigMap integration** for test scripts

### 🔧 **Service** (`templates/service.yaml`)
- **ClusterIP service** for metrics exposure
- **Port 8080** for load testing metrics
- **NetworkPolicy** integration for security
- **Internal DNS** resolution

### 📋 **ConfigMap** (`templates/configmap.yaml`)
```bash
# Contains load testing scripts:
wrk-script.lua:      # Custom WRK Lua script
load-test.sh:        # Main load testing script
metrics-server.py:   # Metrics collection server
hpa-demo.sh:         # HPA demonstration script
```

### 🎯 **Job Template** (`templates/job.yaml`)
- **On-demand execution** capability
- **Configurable parameters** via environment variables
- **Results collection** and logging
- **Resource optimization** for performance

## 🔐 Security Integration

### NetworkPolicy Auto-Generation
The load tester gets secured with NetworkPolicies:

```yaml
# Auto-generated based on app.kubernetes.io/name=load-testing label
- allow-load-testing-access      # Access TO web-server from load-tester
- allow-web-server-load-testing  # Access FROM load-tester TO web-server
- allow-monitoring-access        # Metrics access FROM monitoring
- default-deny-all              # Blocks all other traffic
```

### Pod Security Standards
Complies with **Baseline** Pod Security Standards:
- ✅ **Non-privileged containers**
- ✅ **Host namespaces** restricted
- ✅ **Dangerous capabilities** dropped
- ✅ **Security context** properly configured

## 🚀 Deployment

### Via ArgoCD (Recommended)
```yaml
# argocd-apps/load-testing-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: load-testing
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/anuddeeph1/musical-giggle.git
    targetRevision: gitops
    path: helm-charts/load-testing
  destination:
    server: https://kubernetes.default.svc
    namespace: devops-case-study
```

### Direct Helm Deployment
```bash
# Install load testing
helm install load-testing ./helm-charts/load-testing \
  --namespace devops-case-study \
  --create-namespace

# Install with high-load configuration
helm install load-testing ./helm-charts/load-testing \
  --namespace devops-case-study \
  --values values-high-load.yaml

# Upgrade configuration
helm upgrade load-testing ./helm-charts/load-testing \
  --namespace devops-case-study
```

## 📈 Load Testing Operations

### Manual Load Test Execution
```bash
# Create on-demand load test job
kubectl create job --from=cronjob/load-test-cronjob \
  manual-load-test-$(date +%s) -n devops-case-study

# Monitor test execution
kubectl logs job/manual-load-test-$(date +%s) -n devops-case-study -f

# Check test results
kubectl logs job/manual-load-test-$(date +%s) -n devops-case-study
```

### HPA Demonstration
```bash
# 1. Monitor HPA before test
kubectl get hpa web-server-hpa -n devops-case-study -w &

# 2. Trigger high-load test
kubectl create job --from=cronjob/load-test-cronjob \
  hpa-demo-$(date +%s) -n devops-case-study

# 3. Watch pods scale up
kubectl get pods -l app.kubernetes.io/name=web-server -n devops-case-study -w

# 4. Monitor during test
kubectl top pods -n devops-case-study
```

### Performance Metrics Collection
```bash
# View load test metrics
kubectl port-forward service/load-testing 8080:8080 -n devops-case-study
curl http://localhost:8080/metrics

# Check target service response times
kubectl exec -it deployment/monitoring -n devops-case-study -- \
  curl "http://localhost:9090/api/v1/query?query=http_request_duration_seconds"
```

## 📊 Load Testing Patterns

### Burst Testing
```yaml
# Short, high-intensity tests
loadTest:
  concurrentUsers: 500
  duration: "60s"
  requestRate: 100
  pattern: "burst"
```

### Sustained Load Testing  
```yaml
# Long-duration, moderate load
loadTest:
  concurrentUsers: 50
  duration: "1800s"  # 30 minutes
  requestRate: 5
  pattern: "sustained"
```

### Spike Testing
```yaml
# Sudden load increases
loadTest:
  concurrentUsers: 1000
  duration: "30s"
  requestRate: 200
  pattern: "spike"
```

### Soak Testing
```yaml
# Extended duration testing
loadTest:
  concurrentUsers: 25
  duration: "7200s"  # 2 hours
  requestRate: 2
  pattern: "soak"
```

## 🔧 Troubleshooting

### Load Test Not Starting
```bash
# Check CronJob status
kubectl get cronjobs -n devops-case-study

# View CronJob events
kubectl describe cronjob load-test-cronjob -n devops-case-study

# Check recent jobs
kubectl get jobs -l job-name=load-test-cronjob -n devops-case-study
```

### Low Load Generation
```bash
# Check load tester resource limits
kubectl describe job <job-name> -n devops-case-study

# View load test configuration
kubectl get configmap load-test-config -n devops-case-study -o yaml

# Check network connectivity
kubectl exec -it job/<job-name> -n devops-case-study -- \
  curl http://web-server:8080/health
```

### HPA Not Triggering
```bash
# Check HPA configuration
kubectl describe hpa web-server-hpa -n devops-case-study

# Verify metrics server
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"

# Check resource requests on target
kubectl get deployment web-server -n devops-case-study -o yaml | \
  grep -A 5 resources
```

## 📊 Performance Metrics

### Load Test Results
```bash
# Key metrics collected during tests:
- Requests per second (RPS)
- Average response time
- 95th percentile latency
- Error rate percentage
- Connection errors
- Timeout errors
```

### WRK Output Example
```
Running 5m test @ http://web-server:8080/health
  4 threads and 50 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    12.45ms   4.23ms   89.33ms   87.45%
    Req/Sec     1.02k   156.78     1.45k    84.23%
  Latency Distribution
     50%   11.23ms
     75%   14.56ms
     90%   17.89ms
     99%   25.67ms
  306789 requests in 5.00m, 87.56MB read
Requests/sec:   1022.63
Transfer/sec:    299.45KB
```

### HPA Scaling Metrics
```bash
# Monitor HPA scaling behavior:
kubectl get hpa web-server-hpa -n devops-case-study -o yaml | \
  grep -A 10 status

# Check scaling events
kubectl get events --field-selector involvedObject.name=web-server-hpa \
  -n devops-case-study --sort-by='.metadata.creationTimestamp'
```

## 📋 Values Reference

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `loadTest.targetUrl` | Target service URL | `http://web-server:8080` | Yes |
| `loadTest.targetPath` | Target endpoint path | `/health` | No |
| `loadTest.concurrentUsers` | Number of concurrent users | `50` | No |
| `loadTest.duration` | Test duration | `300s` | No |
| `loadTest.requestRate` | Requests per second per user | `10` | No |
| `loadTest.schedule` | CronJob schedule | `"0 */2 * * *"` | No |
| `loadTest.enabled` | Enable CronJob | `true` | No |
| `image.repository` | Container image repository | `williamyeh/wrk` | Yes |
| `image.tag` | Container image tag | `latest` | No |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` | No |
| `service.port` | Service port for metrics | `8080` | No |
| `resources.limits.cpu` | CPU limit | `1000m` | No |
| `resources.limits.memory` | Memory limit | `512Mi` | No |
| `resources.requests.cpu` | CPU request | `500m` | No |
| `resources.requests.memory` | Memory request | `256Mi` | No |

## 🎯 Use Cases

### 1. **HPA Demonstration**
```bash
# Perfect for showing Kubernetes autoscaling
./scripts/hpa-demo.sh
```

### 2. **Performance Baseline**
```bash
# Establish performance benchmarks
helm install load-testing ./helm-charts/load-testing \
  --set loadTest.pattern=baseline
```

### 3. **Stress Testing**
```bash
# Find breaking points
helm install load-testing ./helm-charts/load-testing \
  --set loadTest.concurrentUsers=1000 \
  --set loadTest.duration=60s
```

### 4. **Regression Testing**
```bash
# Automated performance regression detection
# (via CI/CD integration)
```

## 🔗 Integration Examples

### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "Load Testing Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [{"expr": "rate(http_requests_total[1m])"}]
      },
      {
        "title": "Response Time",
        "targets": [{"expr": "http_request_duration_seconds"}]
      }
    ]
  }
}
```

### Alert Integration
```yaml
# AlertManager rule for load test failures
groups:
- name: load-testing.rules
  rules:
  - alert: LoadTestFailed
    expr: kube_job_status_failed{job_name=~"load-test.*"} > 0
    annotations:
      summary: "Load test failed"
```

## 🔗 Related Documentation

- [📋 Main Project README](../../README.md)
- [🌐 Web Server Helm Chart](../web-server/README.md)
- [💾 Database Helm Chart](../database/README.md)
- [📊 Monitoring Helm Chart](../monitoring/README.md)
- [🛡️ Network Policies](../network-policies/README.md)

---

**🔄 High-performance load testing for HPA and performance validation!** 🚀
