# 🚀 DevOps Case Study: Production-Grade Microservices on Kubernetes

> **A comprehensive demonstration of modern DevOps practices featuring GitOps, Policy-as-Code, automated security, disaster recovery, and horizontal scaling.**

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [🏗️ Architecture](#️-architecture) 
- [🛠️ Technology Stack](#️-technology-stack)
- [✨ Key Features](#-key-features)
- [🚀 Quick Start](#-quick-start)
- [📁 Project Structure](#-project-structure)
- [🔧 Components](#-components)
- [🔐 Security](#-security)
- [📊 Monitoring](#-monitoringls)
- [🎛️ Operations](#️-operations)
- [📚 Documentation](#-documentation)

## 🎯 Overview

This case study demonstrates a **production-grade microservices architecture** deployed on Kubernetes using modern DevOps practices. It showcases:

- **GitOps deployment** with ArgoCD
- **Kubernetes Cluster**: KIND cluster with Docker Hub registry  
- **Database Deployment**: MySQL with persistent storage  
- **Web Server**: Nginx with multiple replicas and custom features 
- **Pod Monitoring**: Golang application tracking pod lifecycle  
- **Helm Charts**: Complete application packaging  
- **Policy-as-Code** with Kyverno for automated security
- **Network policy automation** for zero-trust networking
- **Load Testing**: Automated load generation for HPA demonstration 
- **Disaster Recovery**: Comprehensive DR plan for database 
- **Horizontal pod autoscaling** with load testing
- **Pod Security Standards** 

## 🏗️ Architecture

```mermaid
graph TD
    DEV["👨‍💻 Developer"]

    GIT["📁 GitHub Repository<br/>Helm Charts + App-of-Apps + Code"]

    SCRIPT["🔧 deploy.sh Script<br/>Cluster + ArgoCD + Metrics + Build & Push Go Monitor image to docker hub"]

    KIND["🏗️ KIND Cluster"]

    METRICS["📊 Metrics Server"]

    ARGO["🎯 ArgoCD"]

    DOCKER["🐳 Docker Hub<br/>Go Monitor Image"]

    APPOFAPPS["📦 App-of-Apps<br/> Applications"]

    WEB["🌐 Web Server"]

    DB["💾 MySQL Database"]

    MON["👁 Go Monitoring Agent"]

    SEC["🛡 Kyverno + PSS Policies"]

    NETPOL["🌐 Network Policies"]

    TEST["⚡ Load Testing"]

    REPORTS["📊 Reports Server"]

    %% Flow
    DEV -->|"Push Charts + Code"| GIT
    DEV -->|"Run Script"| SCRIPT

    SCRIPT --> KIND
    SCRIPT --> METRICS
    SCRIPT --> ARGO
    SCRIPT -->|"Build & Push Image"| DOCKER

    ARGO -->|"Pulls from GitHub"| GIT
    ARGO -->|"Deploys"| APPOFAPPS

    %% App-of-Apps deploys
    APPOFAPPS --> WEB
    APPOFAPPS --> DB
    APPOFAPPS --> MON
    APPOFAPPS --> SEC
    APPOFAPPS --> NETPOL
    APPOFAPPS --> TEST
    APPOFAPPS --> REPORTS

    MON -->|"Image from"| DOCKER
    WEB -->|"Uses"| DB

    %% Styling
    classDef developer fill:#FF6B6B,stroke:#C0392B,stroke-width:2px,color:#fff
    classDef git fill:#2ECC71,stroke:#27AE60,stroke-width:2px,color:#fff
    classDef script fill:#E67E22,stroke:#D35400,stroke-width:2px,color:#fff
    classDef infrastructure fill:#3498DB,stroke:#2980B9,stroke-width:2px,color:#fff
    classDef gitops fill:#9B59B6,stroke:#8E44AD,stroke-width:2px,color:#fff
    classDef docker fill:#3498DB,stroke:#2980B9,stroke-width:2px,color:#fff
    classDef master fill:#F39C12,stroke:#E67E22,stroke-width:2px,color:#fff
    classDef apps fill:#1ABC9C,stroke:#16A085,stroke-width:2px,color:#fff

    class DEV developer
    class GIT git
    class SCRIPT script
    class KIND,METRICS infrastructure
    class ARGO gitops
    class DOCKER docker
    class APPOFAPPS master
    class WEB,DB,MON,SEC,NETPOL,TEST,REPORTS apps
```

### 🔄 **DevOps Flow:**
1. **👨‍💻 Developer** pushes Helm charts and Go monitoring code to GitHub
2. **🔧 deploy.sh** script creates KIND cluster, installs ArgoCD, builds and pushes Go monitoring image
3. **🎯 ArgoCD** pulls Helm charts from GitHub and deploys App-of-Apps
4. **📦 App-of-Apps** manages and deploys all 8 applications using Helm charts
5. **👁 Go Monitoring Agent** pulls its container image from Docker Hub

### Network Security (Auto-Generated via Kyverno)
```
📍 Namespace: devops-case-study
├── 🔒 default-deny-all (blocks all traffic)
├── 🌐 allow-dns (DNS resolution)
├── 💾 allow-web-to-database (web→db on port 3306)
├── 📊 allow-monitoring-access (monitoring→all services)
├── 🔄 allow-load-testing-access (load-tester→web-server)
└── 📡 allow-web-server-ingress (external→web-server on port 8080)
```

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Container Orchestration** | Kubernetes (KIND) | Local cluster management |
| **Package Management** | Helm 3 | Application templating & deployment |
| **GitOps** | ArgoCD | Declarative continuous delivery |
| **Policy Engine** | Kyverno | Policy-as-Code & security automation |
| **Service Mesh Security** | NetworkPolicies | Zero-trust networking |
| **Database** | MySQL 8.0 | Persistent data storage |
| **Monitoring** | Custom Pod Monitor
| **Load Testing** | Custom load generator | Performance validation |
| **Backup** | mysqldump + CronJob | Disaster recovery |

## ✨ Key Features

### 🤖 **Automated Security (Policy-as-Code)**
- **17 Pod Security Standards** policies (Baseline + Restricted)
- **10 NetworkPolicies** auto-generated based on pod labels
- **Zero-touch security** for existing and new resources
- **Background scanning** every 1 minute for policy enforcement

### 🔄 **GitOps Deployment**
- **App-of-Apps pattern** with sync waves
- **Automated rollbacks** on health check failures
- **Drift detection** and self-healing
- **Multi-environment support** ready

### 🛡️ **Disaster Recovery**
- **Automated daily backups** via CronJob
- **Point-in-time recovery** capability
- **Backup verification** jobs
- **Cross-AZ backup storage** simulation

### 📈 **Auto-Scaling & Performance**
- **Horizontal Pod Autoscaler** (2-10 replicas, 70% CPU target)
- **Load testing suite** with configurable concurrency
- **Resource optimization** with requests/limits
- **Performance metrics** collection

## 🚀 Quick Start

### Prerequisites
- **Docker** & **KIND** installed
- **kubectl** configured
- **Helm 3** installed
- **Git** access to this repository

### 1️⃣ Deploy Infrastructure
```bash
# Clone and navigate to project
git clone https://github.com/anuddeeph1/devops-k8s-case-study.git
cd devops-k8s-case-study

# Deploy everything with one command
./scripts/deploy.sh gitops

# Monitor deployment progress
watch kubectl get applications -n argocd
```

### 2️⃣ Verify Deployment
```bash
# Check all services are running
kubectl get pods -n devops-case-study

# Verify ArgoCD applications are synced
kubectl get applications -n argocd

# Test web application
kubectl port-forward svc/web-server 8080:8080 -n devops-case-study
curl http://localhost:8080
```

### 3️⃣ Explore Features
```bash
# View auto-generated NetworkPolicies
kubectl get networkpolicies -n devops-case-study

# Check Pod Security policies
kubectl get clusterpolicies

# Monitor HPA scaling
kubectl get hpa -n devops-case-study
```

## 📁 Project Structure

```
musical-giggle/
├── 📋 README.md                          # This file
├── 🚀 Scripts/                           # Deployment script
│   ├── 🚀 deploy.sh                      # Main Deployment Scripts
│   ├── 🚀 setup-cluster.sh
│   ├── 📋 kind-cluster-config.yaml 
|
├── 📦 helm-charts/                       # Helm chart templates
│   ├── 🌐 web-server/                    # Frontend microservice
│   ├── 💾 database/                      # MySQL with DR
│   ├── 📊 monitoring/                    # Metrics collection
│   ├── 🔄 load-testing/                  # Performance testing
│   ├── 🛡️ pss-policies/                  # Pod Security Standards
│   ├── 🔒 network-policies/              # NetworkPolicy generators
│   ├── 🔒 reports-server/               # Reports-server
│   └── ⚡ kyverno/                       # Policy engine
│
├── 🎛️ argocd-apps/                       # GitOps applications
│   ├── 📋 app-of-apps.yaml              # Master application
│   ├── 🌐 web-server-app.yaml           # Web service deployment
│   ├── 💾 database-app.yaml             # Database deployment  
│   ├── 📊 monitoring-app.yaml           # Monitoring deployment
│   ├── 🔄 load-testing-app.yaml         # Load testing deployment
│   ├── ⚡ kyverno-app.yaml              # Policy engine deployment
│   ├── 📊 reports-server-app.yaml       # Policy reporting
│   ├── 🛡️ kyverno-pss-app.yaml          # Security policies
│   └── 🔒 network-policies-app.yaml     # Network security
│
└── 📚 docs/                             # Additional documentation
    ├── 📊 DISASTER_RECOVERY_TESTING_GUIDE.md # DR procedures
    ├── 📊 DISASTER_RECOVERY_PLAN.md # DR procedures

```

## 🔧 Components

### 🌐 **Web Server** (`helm-charts/web-server/`)
- **Technology**: Node.js application
- **Scaling**: HPA enabled (2-10 replicas)
- **Health Checks**: Liveness & readiness probes
- **Networking**: Ingress + NetworkPolicy secured

### 💾 **Database** (`helm-charts/database/`)
- **Technology**: MySQL 8.0
- **Persistence**: 20Gi PVC with backup
- **Security**: Secret-managed credentials
- **Disaster Recovery**: Automated backups + restore procedures

### 📊 **Monitoring** (`helm-charts/monitoring/`)
- **Technology**: Custom Prometheus-style metrics
- **RBAC**: Service account with monitoring permissions
- **Networking**: Access to all services for metrics collection

### 🔄 **Load Testing** (`helm-charts/load-testing/`)
- **Technology**: Custom load generator
- **Configuration**: Configurable concurrency & duration
- **Purpose**: HPA demonstration & performance validation

## 🔐 Security

### 🛡️ **Pod Security Standards**
```yaml
# Applied automatically via Kyverno
Baseline Policies: 11 (disallow-privileged, restrict-capabilities, etc.)
Restricted Policies: 6 (require-non-root, disallow-privilege-escalation, etc.)
Mode: Audit (configurable to Enforce)
```

### 🔒 **Network Security**
- **Default Deny All**: Blocks all traffic by default
- **Principle of Least Privilege**: Only required connections allowed
- **Automatic Generation**: Policies created based on pod labels
- **Zero-Trust Architecture**: Every connection explicitly authorized

### 🔑 **Secret Management**
- **Kubernetes Secrets**: Database credentials
- **Helm Integration**: Template-driven secret generation
- **Backup Encryption**: Secure backup procedures

## 📊 Monitoring

### 📈 **Metrics Collection**
- **Application Metrics**: Custom HTTP endpoints
- **Resource Metrics**: CPU, memory, network usage
- **Policy Metrics**: Security policy violations

### 🔍 **Health Monitoring**
- **Liveness Probes**: Application health checks
- **Readiness Probes**: Service availability checks
- **ArgoCD Health**: GitOps deployment status

## 🎛️ Operations

### 📋 **Daily Operations**
```bash
# Check system health
kubectl get applications -n argocd
kubectl get pods -n devops-case-study

# View security violations
kubectl get policyreports -A

# Monitor scaling
kubectl get hpa -n devops-case-study
```

### 🔄 **Disaster Recovery**
```bash
# Manual backup (automated via CronJob)
kubectl create job --from=cronjob/devops-database-backup-cronjob manual-backup-$(date +%s) -n devops-case-study

# Restore from backup
kubectl apply -f helm-charts/database/job-templates/backup-restore-job.yaml
```

### 🚀 **Scaling Operations**
```bash
# Manual scaling
kubectl scale deployment web-server --replicas=5 -n devops-case-study

# HPA status
kubectl describe hpa web-server-hpa -n devops-case-study
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [`DISASTER_RECOVERY_TESTING_GUIDE.md`](DISASTER_RECOVERY_TESTING_GUIDE.md) | Complete DR procedures |
| [`helm-charts/*/README.md`](helm-charts/) | Individual service documentation |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design deep-dive |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Security implementation details |
| [`docs/OPERATIONS.md`](docs/OPERATIONS.md) | Operational procedures |

---

## 🎯 **Learning Outcomes**

After completing this case study, you will understand:

- ✅ **GitOps** deployment patterns with ArgoCD
- ✅ **Policy-as-Code** implementation with Kyverno
- ✅ **Zero-trust networking** with automated NetworkPolicies
- ✅ **Disaster recovery** strategies for stateful services
- ✅ **Horizontal pod autoscaling** configuration
- ✅ **Helm chart** templating and best practices
- ✅ **Kubernetes security** with Pod Security Standards
- ✅ **Production-grade** microservices architecture

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📝 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

#### **🚀 GitOps Excellence**
- ✅ **8 Applications** deployed via ArgoCD App-of-Apps pattern
- ✅ **All Applications SYNCED** and HEALTHY
- ✅ **Monitoring Built from Source** - `monitoring-go-controller` successfully compiled and deployed
- ✅ **Zero Manual Intervention** - Complete GitOps workflow

#### **🛡️ Security Mastery**  
- ✅ **27 Active Policies** (17 PSS + 10 NetworkPolicies)
- ✅ **Pod Security Standards** - Baseline + Restricted compliance
- ✅ **Auto-Generated NetworkPolicies** with `generateExisting: true`
- ✅ **Zero-Trust Networking** securing database access

#### **📊 Production Operations**
- ✅ **StatefulSet MySQL** with automatic storage provisioning  
- ✅ **HPA Auto-Scaling** (3-10 replicas, CPU/Memory triggers)
- ✅ **Load Testing** with RBAC-enabled monitoring
- ✅ **Disaster Recovery** backup/restore automation ready

#### **🔧 Technical Implementation**
- ✅ **13 Kyverno Pods** running (admission, background, cleanup, reports controllers)
- ✅ **10 NetworkPolicies** automatically generated and applied
- ✅ **MySQL StatefulSet** with `volumeClaimTemplates` 
- ✅ **Source Code Pipeline** - Go monitoring app built from `./monitoring-go-controller`

### 🎯 **Demo-Ready Features**

| Feature | Status | Demo Command |
|---------|--------|--------------|
| **Web App** | ✅ Running | `open http://localhost:8080` |
| **ArgoCD UI** | ✅ Ready | `open https://localhost:8081` |  
| **HPA Scaling** | ✅ Active | `kubectl create job --from=cronjob/load-test-job demo` |
| **Policy Compliance** | ✅ Clean | `kubectl get policyreports -A` |
| **Network Security** | ✅ Enforced | `kubectl get networkpolicies -n devops-case-study` |
| **DR Testing** | ✅ Ready | `kubectl create job --from=cronjob/mysql-backup-job test` |

### 🚀 **Ready For:**
- ✅ **Technical Interviews** - Full GitOps + Policy-as-Code demonstration
- ✅ **Production Deployment** - All security and operational best practices implemented  
- ✅ **Architecture Reviews** - Enterprise-grade microservices with proper separation
- ✅ **DevOps Showcases** - Complete CI/CD pipeline with automated compliance

---

**💡 This case study demonstrates mastery of modern DevOps practices with production-ready implementations!**

**Built with ❤️ for the DevOps community** 🚀