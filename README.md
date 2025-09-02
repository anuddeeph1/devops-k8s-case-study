# DevOps Case Study - Complete Kubernetes Deployment

This repository contains a comprehensive DevOps case study implementation that demonstrates modern containerization, orchestration, monitoring, and scaling practices using Kubernetes.

## 🎯 Project Overview

The solution implements a complete web application stack with:
- **Web Server**: Nginx with custom configuration and dynamic content
- **Database**: MySQL with persistent storage
- **Monitoring**: Golang-based pod lifecycle monitoring
- **Autoscaling**: Horizontal Pod Autoscaler (HPA) with load testing
- **Security**: Network policies restricting database access
- **Infrastructure**: KIND cluster with Docker Hub registry
- **Packaging**: Helm charts for complete deployment

## 📋 Requirements Implemented

✅ **1. Kubernetes Cluster**: KIND cluster with Docker Hub registry  
✅ **2. Database Deployment**: MySQL with persistent storage  
✅ **3. Web Server**: Nginx with multiple replicas and custom features  
✅ **4. Network Policies**: Restricted database access  
✅ **5. Horizontal Pod Autoscaler**: CPU and memory-based scaling  
✅ **6. Load Testing**: Automated load generation for HPA demonstration  
✅ **7. Disaster Recovery**: Comprehensive DR plan for database  
✅ **8. Pod Monitoring**: Golang application tracking pod lifecycle  
✅ **9. Helm Charts**: Complete application packaging  

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    KIND Kubernetes Cluster                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Web Server    │    │    Database     │                │
│  │   (Nginx 3x)    │    │   (MySQL 1x)    │                │
│  │                 │    │                 │                │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │                │
│  │ │Init Container│ │    │ │Persistent Vol│ │                │
│  │ │Dynamic HTML │ │    │ │   Storage   │ │                │
│  │ └─────────────┘ │    │ └─────────────┘ │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           │    ┌─────────────────┐│                        │
│           │    │  Network Policy ││                        │
│           └────┤   Port 3306     ├┘                        │
│                └─────────────────┘                         │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │      HPA        │    │  Pod Monitor    │                │
│  │   (Scaling)     │    │   (Golang)      │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  Load Testing   │    │    Ingress      │                │
│  │    (Alpine)     │    │   (Nginx)       │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

Install the following tools:
```bash
# macOS
brew install kind kubectl helm docker

# Verify Go is installed (for building monitoring app)
go version

# Login to Docker Hub (required for pushing custom images)
docker login
```

### One-Command Deployment

```bash
# Make deployment script executable
chmod +x deploy.sh

# Deploy everything
./deploy.sh deploy
```

This will:
1. Create KIND cluster with metrics-server for HPA
2. Build and push the monitoring application to Docker Hub
3. Deploy all components to Kubernetes
4. Set up port forwarding
5. Run basic tests

### Access the Application

After deployment completes:
- **Web Application**: http://localhost:8080
- **Database**: localhost:3306 (root/root123)

## 🧪 Testing and Demonstration

### 1. View the Web Application
```bash
# The web page shows:
# - Pod IP address
# - Serving host (Host-{last5chars})
# - Pod name
# - Node name
open http://localhost:8080
```

### 2. Test Horizontal Pod Autoscaler
```bash
# Run load test to trigger scaling
./deploy.sh test

# Monitor HPA and pod scaling
watch kubectl get hpa,pods -n devops-case-study
```

### 3. Monitor Pod Lifecycle Changes
```bash
# View pod monitor logs
kubectl logs -f deployment/pod-monitor -n devops-case-study

# In another terminal, scale web server to see events
kubectl scale deployment web-server --replicas=5 -n devops-case-study
```

### 4. Test Network Policies
```bash
# Try to access MySQL from a non-web-server pod (should fail)
kubectl run test-pod --rm -it --image=mysql:8.0 -n devops-case-study -- \
  mysql -h mysql-service -u root -proot123 -e "SELECT 1"
```

## 📁 Project Structure

```
.
├── README.md
├── deploy.sh                      # One-command deployment script
├── setup-cluster.sh              # KIND cluster setup
├── kind-cluster-config.yaml      # KIND configuration
├── database/                     # Database components
│   ├── mysql-deployment.yaml
│   ├── mysql-pv.yaml
│   └── network-policy.yaml
├── web-server/                   # Web server components
│   ├── web-server-deployment.yaml
│   ├── hpa.yaml
│   ├── nginx.conf
│   └── index.html.template
├── monitoring/                   # Pod monitoring application
│   ├── main.go
│   ├── go.mod
│   ├── Dockerfile
│   └── pod-monitor-deployment.yaml
├── load-testing/                 # Load testing setup
│   └── load-test-deployment.yaml
├── helm-charts/                  # Helm chart packaging
│   └── devops-case-study/
└── docs/                        # Documentation
    └── disaster-recovery-plan.md
```

## 🔧 Component Details

### Web Server Features
- **Multiple Replicas**: 3 pods by default, scales up to 10
- **Custom Configuration**: Nginx configuration mounted as ConfigMap
- **Init Container**: Dynamically populates HTML with pod information
- **Health Checks**: `/health` and `/status` endpoints
- **Auto-refresh**: Web page refreshes every 30 seconds

### Database Features
- **Persistent Storage**: 10Gi PersistentVolume for data persistence
- **Health Checks**: Liveness and readiness probes
- **Security**: Network policies restrict access to web server pods only
- **Backup Strategy**: Documented disaster recovery plan

### Monitoring Application
- **Golang**: Built with Kubernetes client-go library
- **Real-time**: Watches for pod create, update, delete events
- **JSON Logging**: Structured logs for easy parsing
- **RBAC**: Proper service account and cluster role

### Autoscaling
- **CPU Scaling**: Targets 70% CPU utilization
- **Memory Scaling**: Targets 80% memory utilization
- **Scaling Behavior**: Configurable scale-up/scale-down policies
- **Load Testing**: Automated load generation for demonstration

## 🛡️ Security Features

### Network Policies
- Database pods only accept connections from web server pods on port 3306
- Web server pods can reach database but not other services
- Default deny policy for enhanced security

### RBAC
- Service accounts with minimal required permissions
- ClusterRole for pod monitoring with read-only access
- Secrets for database credentials

## 📊 Monitoring and Observability

### Pod Lifecycle Monitoring
The Golang monitoring application tracks:
- **New pods created**: Real-time notification when pods start
- **Pod deletions**: Immediate alerts when pods are terminated
- **Pod updates**: Phase changes, restarts, condition changes

### Example Monitor Output
```json
{"timestamp":"2024-01-15T10:30:45.123Z","event_type":"ADDED","pod_name":"web-server-7f89cf47bf-25gxj","namespace":"devops-case-study","pod_ip":"10.244.0.15","node_name":"devops-case-study-worker","phase":"Running","message":"New pod created"}
```

## 📈 Scaling Demonstration

### Load Testing Scenarios
1. **Baseline**: 3 web server replicas
2. **Load Generation**: 20 concurrent users for 5 minutes
3. **Scaling**: HPA increases replicas to handle load
4. **Scale Down**: Replicas reduce when load decreases

### Expected Behavior
- CPU utilization increases under load
- HPA creates additional pods when CPU > 70%
- Load distributes across multiple pods
- Automatic scale-down after load test completes

## 🗂️ Disaster Recovery

The database includes a comprehensive disaster recovery plan covering:

### Strategies
- **Master-Slave Replication**: For real-time backup
- **Automated Backups**: Daily full backups, hourly incrementals
- **Multi-Zone Deployment**: High availability across zones
- **Storage Replication**: Persistent volume snapshots

### Recovery Scenarios
- Pod failure (RTO: 2-5 minutes)
- Node failure (RTO: 5-10 minutes) 
- Storage failure (RTO: 15-30 minutes)
- Cluster failure (RTO: 1-2 hours)
- Data center failure (RTO: 30 minutes - 1 hour)

## 🧹 Cleanup

```bash
# Clean up everything
./deploy.sh cleanup

# Or manually
kind delete cluster --name devops-case-study
docker stop kind-registry && docker rm kind-registry
```

## 📝 Technical Decisions and Assumptions

### Assumptions Made
1. **Local Development**: Using KIND for cluster (production would use managed Kubernetes)
2. **Single Database**: MySQL deployed as single pod (production would use StatefulSet or managed DB)
3. **Local Registry**: Using localhost:5001 registry for custom images
4. **Network**: Assuming basic network connectivity for ingress

### Technical Decisions
1. **Init Container Approach**: Chosen for dynamic HTML generation over sidecar pattern
2. **ConfigMaps**: Used for configuration management instead of baking into images
3. **Golang Monitoring**: Selected for performance and Kubernetes client library support
4. **Alpine Linux**: Used in containers for smaller image sizes
5. **Network Policies**: Implemented default-deny approach for security

### Areas for Improvement
1. **Database High Availability**: Implement MySQL clustering or use managed database
2. **Observability**: Add Prometheus metrics and Grafana dashboards
3. **CI/CD Pipeline**: Implement GitOps workflow with ArgoCD
4. **Security**: Add Pod Security Standards and image vulnerability scanning
5. **Backup Automation**: Implement automated backup verification and restoration testing

## 🎯 Demonstration Points

This implementation showcases:
- **Container Orchestration**: Multi-component Kubernetes deployment
- **Configuration Management**: ConfigMaps and Secrets for application config
- **Scaling**: Horizontal Pod Autoscaler responding to load
- **Monitoring**: Custom application monitoring pod lifecycle
- **Security**: Network policies and RBAC implementation  
- **Packaging**: Helm charts for reproducible deployments
- **Documentation**: Comprehensive disaster recovery planning

## 📞 Support

For questions or issues with this implementation:
1. Check the logs: `kubectl logs -n devops-case-study <pod-name>`
2. View status: `./deploy.sh status`
3. Review component health: `kubectl get all -n devops-case-study`

---

**Note**: This is a demonstration environment. For production use, consider managed Kubernetes services, proper backup solutions, monitoring stack, and security hardening.
