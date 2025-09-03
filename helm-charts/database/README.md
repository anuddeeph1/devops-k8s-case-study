# 💾 Database Helm Chart

> **Production-grade MySQL 8.0 with automated disaster recovery and comprehensive backup strategy**

## 📋 Overview

The **database** chart deploys a robust MySQL 8.0 database with:
- **Automated disaster recovery** with scheduled backups
- **Point-in-time recovery** capability
- **Cross-AZ backup simulation** with persistent storage
- **Secret-managed credentials** for security
- **Network policy integration** for zero-trust security
- **Resource optimization** for stable performance

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Server    │────│     MySQL       │────│  Backup Storage │
│   (Frontend)    │    │   (Primary)     │    │   (5Gi PVC)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                │                       │
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Monitoring    │    │  Backup CronJob │
                       │   (Metrics)     │    │  (every 6 hours)│
                       └─────────────────┘    └─────────────────┘
```

## 🔐 Disaster Recovery

### 🔄 **Automated Backup Strategy**

#### Daily Automated Backups
```yaml
# CronJob runs daily at 2:00 AM UTC
schedule: "0 2 * * *"
backupRetention: 30 # Keep 30 days of backups
```

#### Backup Components
- **📦 Backup PVC**: 20Gi persistent storage for backup files
- **⏰ Backup CronJob**: Daily scheduled backups with rotation
- **🔧 Backup ConfigMap**: Backup and restore scripts
- **🔑 Secret Integration**: Secure database credential access

#### Backup Verification
```bash
# Automatic backup verification (runs after each backup)
├── Database connectivity test
├── Backup file integrity check  
├── Backup size validation
└── Timestamp verification
```

### 📊 **Recovery Procedures**

#### On-Demand Backup
```bash
# Create manual backup job
kubectl create job --from=cronjob/devops-database-backup-cronjob \
  manual-backup-$(date +%s) -n devops-case-study
```

#### Point-in-Time Restore
```bash
# Apply restore job template
kubectl apply -f job-templates/backup-restore-job.yaml

# Monitor restore progress
kubectl logs job/devops-database-restore-job -n devops-case-study -f
```

#### Backup Verification
```bash
# Run backup verification job
kubectl apply -f job-templates/backup-verify-job.yaml

# Check verification results
kubectl logs job/devops-database-backup-verify-job -n devops-case-study
```

## 🔧 Configuration

### Default Values (`values.yaml`)

```yaml
# MySQL configuration
mysql:
  # Database settings
  rootPassword: rootpassword123
  database: devops_db
  user: devops_user
  password: userpassword123
  
  # Disaster Recovery
  backup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM UTC
    retention: 30          # Keep 30 days
    storage: 20Gi         # Backup storage size
  
# Resource management
resources:
  limits:
    cpu: 1000m
    memory: 1024Mi
  requests:
    cpu: 500m
    memory: 512Mi

# Persistence
persistence:
  enabled: true
  size: 20Gi
  storageClass: ""  # Use default storage class
```

### Production Configuration Example

```yaml
# values-prod.yaml
mysql:
  rootPassword: ${MYSQL_ROOT_PASSWORD}  # From secret manager
  database: production_db
  user: app_user
  password: ${MYSQL_USER_PASSWORD}      # From secret manager
  
  backup:
    enabled: true
    schedule: "0 1 * * *"  # Daily at 1 AM UTC
    retention: 90          # Keep 90 days for compliance
    storage: 100Gi         # Larger backup storage

resources:
  limits:
    cpu: 2000m
    memory: 4096Mi
  requests:
    cpu: 1000m
    memory: 2048Mi

persistence:
  size: 100Gi
  storageClass: "fast-ssd"
```

## 📦 Components

### 🚀 **Deployment** (`templates/deployment.yaml`)
- **MySQL 8.0** container with optimized configuration
- **Persistent storage** mounting for data durability
- **Health probes** for availability monitoring
- **Resource limits** for performance stability
- **Security context** with proper user permissions

### 🔑 **Secret** (`templates/secret.yaml`)
```yaml
# Automatically generated secret containing:
- MYSQL_ROOT_PASSWORD: Root user password
- MYSQL_USER: Application user name
- MYSQL_PASSWORD: Application user password
- MYSQL_DATABASE: Database name
```

### 🔧 **Service** (`templates/service.yaml`)
- **ClusterIP service** on port 3306
- **Internal DNS** resolution (`mysql.devops-case-study.svc.cluster.local`)
- **NetworkPolicy** integration for security

### 💾 **PersistentVolumeClaim** (`templates/pvc.yaml`)
- **Data storage**: 20Gi (configurable)
- **Backup storage**: Additional 20Gi PVC for backups
- **Retention policy**: Retain for disaster recovery

### ⏰ **Backup CronJob** (`templates/backup-cronjob.yaml`)
```yaml
# Automated daily backups with:
schedule: "0 2 * * *"           # 2 AM daily
backupRetention: 30 days        # Automatic cleanup
mysqldump: --all-databases      # Full database backup
compression: gzip               # Space optimization
verification: automatic         # Integrity checks
```

### 📋 **ConfigMap** (`templates/backup-configmap.yaml`)
```bash
# Contains backup and restore scripts:
backup.sh:    # Full database backup with compression
restore.sh:   # Point-in-time database restore  
verify.sh:    # Backup integrity verification
cleanup.sh:   # Old backup cleanup (30+ days)
```

## 🔐 Security Integration

### NetworkPolicy Auto-Generation
The database is automatically secured with NetworkPolicies:

```yaml
# Auto-generated based on app.kubernetes.io/name=database label
- allow-web-to-database        # Web server access on port 3306
- allow-database-monitoring    # Monitoring access from monitoring pods
- default-deny-all            # Blocks all other traffic
```

### Secret Management
- **Kubernetes Secrets** for credential storage
- **Environment variable** injection into containers
- **Base64 encoding** with proper RBAC access controls
- **Backup encryption** for disaster recovery

### Pod Security Standards
Complies with **Baseline** Pod Security Standards:
- ✅ **Privileged containers** disallowed
- ✅ **Host namespaces** restricted
- ✅ **Dangerous capabilities** dropped
- ✅ **Root filesystem** writable (required for MySQL)

## 📊 Monitoring & Health Checks

### Database Health Probes
```yaml
# Liveness Probe
livenessProbe:
  exec:
    command: ["mysqladmin", "ping"]
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5

# Readiness Probe
readinessProbe:
  exec:
    command: ["mysql", "-h", "127.0.0.1", "-e", "SELECT 1"]
  initialDelaySeconds: 5
  periodSeconds: 2
```

### Backup Monitoring
```bash
# Check backup job status
kubectl get cronjobs -n devops-case-study

# View recent backup logs
kubectl logs cronjob/devops-database-backup-cronjob -n devops-case-study

# List backup files
kubectl exec deployment/mysql -n devops-case-study -- \
  ls -la /var/lib/mysql-backup/
```

## 🚀 Deployment

### Via ArgoCD (Recommended)
```yaml
# argocd-apps/database-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devops-database
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/anuddeeph1/musical-giggle.git
    targetRevision: gitops
    path: helm-charts/database
  destination:
    server: https://kubernetes.default.svc
    namespace: devops-case-study
```

### Direct Helm Deployment
```bash
# Install with default values
helm install devops-database ./helm-charts/database \
  --namespace devops-case-study \
  --create-namespace

# Install with production values
helm install devops-database ./helm-charts/database \
  --namespace devops-case-study \
  --values values-prod.yaml

# Upgrade existing installation
helm upgrade devops-database ./helm-charts/database \
  --namespace devops-case-study
```

## 💾 Disaster Recovery Operations

### 📋 **Complete Backup & Restore Guide**

See [`../../DISASTER_RECOVERY_TESTING_GUIDE.md`](../../DISASTER_RECOVERY_TESTING_GUIDE.md) for comprehensive procedures.

#### Quick Backup Operations
```bash
# 1. Manual backup
kubectl create job --from=cronjob/devops-database-backup-cronjob \
  manual-backup-$(date +%s) -n devops-case-study

# 2. List available backups
kubectl exec deployment/mysql -n devops-case-study -- \
  ls -la /var/lib/mysql-backup/

# 3. Verify backup integrity  
kubectl apply -f job-templates/backup-verify-job.yaml
```

#### Emergency Restore Procedure
```bash
# 1. Scale down applications
kubectl scale deployment web-server --replicas=0 -n devops-case-study

# 2. Create restore job
kubectl apply -f job-templates/backup-restore-job.yaml

# 3. Monitor restore progress
kubectl logs job/devops-database-restore-job -n devops-case-study -f

# 4. Verify data integrity
kubectl exec deployment/mysql -n devops-case-study -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"

# 5. Scale up applications
kubectl scale deployment web-server --replicas=2 -n devops-case-study
```

## 🔧 Troubleshooting

### Database Connection Issues
```bash
# Check database pod status
kubectl get pods -l app.kubernetes.io/name=database -n devops-case-study

# View database logs
kubectl logs deployment/mysql -n devops-case-study

# Test database connectivity
kubectl exec -it deployment/mysql -n devops-case-study -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1;"
```

### Backup Issues
```bash
# Check CronJob status
kubectl get cronjobs -n devops-case-study

# View recent backup job logs
kubectl logs -l job-name=devops-database-backup-cronjob -n devops-case-study

# Check backup storage
kubectl exec deployment/mysql -n devops-case-study -- \
  df -h /var/lib/mysql-backup/
```

### Persistence Issues
```bash
# Check PVC status
kubectl get pvc -n devops-case-study

# Check PV details
kubectl describe pv $(kubectl get pvc mysql-pvc -n devops-case-study -o jsonpath='{.spec.volumeName}')

# Verify mount points
kubectl exec deployment/mysql -n devops-case-study -- \
  mount | grep mysql
```

## 📋 Job Templates

### Available Templates (`job-templates/`)

| Template | Purpose | Usage |
|----------|---------|-------|
| `backup-restore-job.yaml` | Point-in-time restore | `kubectl apply -f job-templates/backup-restore-job.yaml` |
| `backup-verify-job.yaml` | Backup integrity check | `kubectl apply -f job-templates/backup-verify-job.yaml` |
| `README.md` | Job template documentation | Reference guide |

### Job Template Usage
```bash
# 1. Navigate to job templates
cd helm-charts/database/job-templates/

# 2. Review available templates
ls -la

# 3. Apply desired template
kubectl apply -f backup-restore-job.yaml

# 4. Monitor job execution
kubectl get jobs -n devops-case-study
kubectl logs job/<job-name> -n devops-case-study
```

## 📊 Values Reference

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `mysql.rootPassword` | MySQL root password | `rootpassword123` | Yes |
| `mysql.database` | Database name | `devops_db` | Yes |
| `mysql.user` | Application username | `devops_user` | Yes |
| `mysql.password` | Application password | `userpassword123` | Yes |
| `mysql.backup.enabled` | Enable automated backups | `true` | No |
| `mysql.backup.schedule` | Backup cron schedule | `"0 2 * * *"` | No |
| `mysql.backup.retention` | Backup retention days | `30` | No |
| `mysql.backup.storage` | Backup storage size | `20Gi` | No |
| `persistence.enabled` | Enable persistent storage | `true` | No |
| `persistence.size` | Database storage size | `20Gi` | No |
| `persistence.storageClass` | Storage class name | `""` | No |
| `resources.limits.cpu` | CPU limit | `1000m` | No |
| `resources.limits.memory` | Memory limit | `1024Mi` | No |
| `resources.requests.cpu` | CPU request | `500m` | No |
| `resources.requests.memory` | Memory request | `512Mi` | No |

## 📈 Performance Tuning

### MySQL Optimization
```yaml
# Custom MySQL configuration via ConfigMap
mysql:
  config: |
    [mysqld]
    innodb_buffer_pool_size = 512M
    innodb_log_file_size = 256M
    max_connections = 200
    query_cache_size = 32M
```

### Resource Scaling
```bash
# Scale resources for production
helm upgrade devops-database ./helm-charts/database \
  --set resources.limits.cpu=2000m \
  --set resources.limits.memory=2048Mi \
  --set resources.requests.cpu=1000m \
  --set resources.requests.memory=1024Mi \
  --namespace devops-case-study
```

## 🔗 Related Documentation

- [📋 Main Project README](../../README.md)
- [🌐 Web Server Helm Chart](../web-server/README.md)
- [📊 Monitoring Helm Chart](../monitoring/README.md)  
- [💾 Disaster Recovery Guide](../../DISASTER_RECOVERY_TESTING_GUIDE.md)
- [🔧 Job Templates](./job-templates/README.md)

---

**💾 Production-ready database with bulletproof disaster recovery!** 🚀
