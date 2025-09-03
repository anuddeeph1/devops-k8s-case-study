# 🛠️ Database Job Templates

> **On-demand disaster recovery operations for MySQL database backup and restore**

## 📋 Overview

This directory contains **Kubernetes Job templates** for manual disaster recovery operations:
- **Point-in-time database restore** from backups
- **Backup integrity verification** and validation
- **Emergency recovery procedures** for production incidents

⚠️ **Important**: These are **manual job templates** that are **NOT** deployed by ArgoCD automatically. They are designed for **on-demand execution** during disaster recovery scenarios.

## 🏗️ Architecture

```
💾 Disaster Recovery Job Templates

┌───────────────────────────────────────────────────────────────┐
│                    Manual DR Operations                       │
│                                                               │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │ Backup Storage  │    │   MySQL Pod     │                   │
│  │  (20Gi PVC)     │    │  (Production)   │                   │
│  │                 │    │                 │                   │
│  │ • backup files  │────│ • live data     │                   │
│  │ • retention     │    │ • transactions  │                   │
│  │ • compression   │    │ • connections   │                   │
│  └─────────────────┘    └─────────────────┘                   │
│           │                       │                           │
│           └───────────┬───────────┘                           │
│                       │                                       │
│              ┌─────────────────┐                              │
│              │  Job Templates  │                              │
│              │   (On-Demand)   │                              │
│              │                 │                              │
│              │ • Restore Job   │                              │
│              │ • Verify Job    │                              │
│              └─────────────────┘                              │
│                                                               │
└───────────────────────────────────────────────────────────────┘

🎯 Usage Pattern:
Emergency → Apply Template → Monitor Job → Verify Results → Resume Operations
```

## 📦 Available Templates

### 🔄 **backup-restore-job.yaml** - Point-in-Time Database Restore

#### Purpose
Restores MySQL database from the most recent backup file during disaster recovery scenarios.

#### When to Use
- **Data corruption** incidents
- **Accidental data deletion**
- **Database migration** requirements
- **Testing disaster recovery** procedures

#### Features
```yaml
# Complete database restoration:
- Connects to MySQL using root credentials
- Drops existing database (if exists)  
- Imports from latest backup file
- Verifies restoration success
- Provides detailed logging
```

#### Usage
```bash
# Apply restore job template
kubectl apply -f job-templates/backup-restore-job.yaml

# Monitor restoration progress  
kubectl logs job/devops-database-restore-job -n devops-case-study -f

# Check job completion
kubectl get job devops-database-restore-job -n devops-case-study
```

### ✅ **backup-verify-job.yaml** - Backup Integrity Verification

#### Purpose
Validates backup file integrity and ensures backup process is working correctly.

#### When to Use
- **Regular backup validation** (monthly recommended)
- **Pre-disaster recovery testing**
- **Backup process debugging**
- **Compliance verification** requirements

#### Features
```yaml
# Comprehensive backup validation:
- Tests backup file existence
- Validates file integrity and size
- Checks backup timestamp
- Verifies MySQL connectivity
- Reports validation results
```

#### Usage
```bash
# Apply verification job template
kubectl apply -f job-templates/backup-verify-job.yaml

# Monitor verification progress
kubectl logs job/devops-database-backup-verify-job -n devops-case-study -f

# Check verification results
kubectl get job devops-database-backup-verify-job -n devops-case-study
```

## 🚨 Emergency Procedures

### 🔥 **Complete Disaster Recovery Workflow**

#### **Phase 1: Assessment** 
```bash
# 1. Assess the situation
kubectl get pods -n devops-case-study
kubectl logs deployment/mysql -n devops-case-study --tail=50

# 2. Check backup availability
kubectl exec deployment/mysql -n devops-case-study -- \
  ls -la /var/lib/mysql-backup/

# 3. Scale down applications to prevent data conflicts
kubectl scale deployment web-server --replicas=0 -n devops-case-study
kubectl scale deployment load-tester --replicas=0 -n devops-case-study
```

#### **Phase 2: Database Restore**
```bash
# 4. Apply restore job
kubectl apply -f job-templates/backup-restore-job.yaml

# 5. Monitor restoration (this may take several minutes)
kubectl logs job/devops-database-restore-job -n devops-case-study -f

# 6. Verify job completion
kubectl get job devops-database-restore-job -n devops-case-study
```

#### **Phase 3: Validation**
```bash
# 7. Test database connectivity
kubectl exec deployment/mysql -n devops-case-study -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"

# 8. Verify data integrity
kubectl exec deployment/mysql -n devops-case-study -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "USE devops_db; SHOW TABLES;"

# 9. Run backup verification
kubectl apply -f job-templates/backup-verify-job.yaml
```

#### **Phase 4: Service Recovery**  
```bash
# 10. Scale applications back up
kubectl scale deployment web-server --replicas=2 -n devops-case-study
kubectl scale deployment load-tester --replicas=1 -n devops-case-study

# 11. Verify full service functionality
kubectl get pods -n devops-case-study
kubectl port-forward service/web-server 8080:8080 -n devops-case-study
curl http://localhost:8080/health
```

#### **Phase 5: Cleanup**
```bash
# 12. Clean up completed jobs  
kubectl delete job devops-database-restore-job -n devops-case-study
kubectl delete job devops-database-backup-verify-job -n devops-case-study
```

## 📋 Template Details

### 🔄 **Restore Job Template**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: devops-database-restore-job
  namespace: devops-case-study
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: mysql-restore
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        volumeMounts:
        - name: mysql-backup-storage
          mountPath: /var/lib/mysql-backup
        command: ["/bin/bash"]
        args: 
        - -c
        - |
          echo "🔄 Starting MySQL database restore..."
          
          # Find latest backup
          LATEST_BACKUP=$(ls -t /var/lib/mysql-backup/backup-*.sql.gz 2>/dev/null | head -1)
          
          if [ -z "$LATEST_BACKUP" ]; then
            echo "❌ No backup file found!"
            exit 1
          fi
          
          echo "📦 Found backup: $LATEST_BACKUP"
          
          # Restore database
          echo "🔄 Restoring database from backup..."
          zcat "$LATEST_BACKUP" | mysql -h mysql-service -u root -p$MYSQL_ROOT_PASSWORD
          
          if [ $? -eq 0 ]; then
            echo "✅ Database restore completed successfully!"
          else
            echo "❌ Database restore failed!"
            exit 1
          fi
      volumes:
      - name: mysql-backup-storage
        persistentVolumeClaim:
          claimName: mysql-backup-pvc
```

### ✅ **Verification Job Template**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: devops-database-backup-verify-job
  namespace: devops-case-study
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: backup-verify
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        volumeMounts:
        - name: mysql-backup-storage
          mountPath: /var/lib/mysql-backup
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "🔍 Starting backup verification..."
          
          # Check backup files exist
          BACKUP_COUNT=$(ls /var/lib/mysql-backup/backup-*.sql.gz 2>/dev/null | wc -l)
          echo "📊 Found $BACKUP_COUNT backup files"
          
          if [ $BACKUP_COUNT -eq 0 ]; then
            echo "❌ No backup files found!"
            exit 1
          fi
          
          # Get latest backup info
          LATEST_BACKUP=$(ls -t /var/lib/mysql-backup/backup-*.sql.gz | head -1)
          BACKUP_SIZE=$(stat -c%s "$LATEST_BACKUP")
          BACKUP_DATE=$(stat -c%y "$LATEST_BACKUP")
          
          echo "📦 Latest backup: $(basename $LATEST_BACKUP)"
          echo "📏 Backup size: $BACKUP_SIZE bytes"
          echo "📅 Backup date: $BACKUP_DATE"
          
          # Verify backup is not empty and recent
          if [ $BACKUP_SIZE -lt 1000 ]; then
            echo "⚠️  WARNING: Backup size seems too small!"
          fi
          
          # Test database connectivity
          echo "🔍 Testing database connectivity..."
          mysql -h mysql-service -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1;" >/dev/null 2>&1
          
          if [ $? -eq 0 ]; then
            echo "✅ Database connectivity verified!"
          else
            echo "❌ Database connectivity failed!"
            exit 1
          fi
          
          echo "✅ Backup verification completed successfully!"
      volumes:
      - name: mysql-backup-storage
        persistentVolumeClaim:
          claimName: mysql-backup-pvc
```

## 🔧 Troubleshooting

### Job Not Starting
```bash
# Check job status
kubectl describe job <job-name> -n devops-case-study

# Verify PVC exists
kubectl get pvc mysql-backup-pvc -n devops-case-study

# Check secret availability
kubectl get secret mysql-secret -n devops-case-study
```

### Restore Failures
```bash
# Check job logs for errors
kubectl logs job/devops-database-restore-job -n devops-case-study

# Verify backup file integrity
kubectl exec deployment/mysql -n devops-case-study -- \
  ls -la /var/lib/mysql-backup/

# Test backup file manually
kubectl exec deployment/mysql -n devops-case-study -- \
  gzip -t /var/lib/mysql-backup/backup-*.sql.gz
```

### Database Connection Issues
```bash
# Verify MySQL service
kubectl get service mysql-service -n devops-case-study

# Check MySQL pod logs
kubectl logs deployment/mysql -n devops-case-study --tail=30

# Test direct connection
kubectl exec -it deployment/mysql -n devops-case-study -- \
  mysql -u root -p
```

## 📊 Monitoring & Alerting

### Job Status Monitoring
```bash
# Monitor job progress
kubectl get jobs -n devops-case-study -w

# Check job events
kubectl get events --field-selector involvedObject.kind=Job \
  -n devops-case-study --sort-by='.metadata.creationTimestamp'
```

### Backup Health Metrics
```bash
# Check backup file count and sizes
kubectl exec deployment/mysql -n devops-case-study -- \
  bash -c 'ls -lh /var/lib/mysql-backup/ | grep -E "backup-.*\.sql\.gz"'

# Monitor backup storage usage
kubectl exec deployment/mysql -n devops-case-study -- \
  df -h /var/lib/mysql-backup/
```

## ⚠️ Important Notes

### 🚨 **Pre-Execution Checklist**
- [ ] **Scale down applications** accessing the database
- [ ] **Verify backup file existence** and integrity
- [ ] **Confirm maintenance window** for restore operations
- [ ] **Notify stakeholders** of planned downtime
- [ ] **Test restore procedure** in development first

### 🔒 **Security Considerations**
- Jobs run with **same credentials** as production database
- **Backup files contain sensitive data** - ensure proper access controls
- **Network policies** may affect job execution - verify connectivity
- **RBAC permissions** required for job creation and monitoring

### 📈 **Performance Impact**
- **Restore operations** may take significant time for large databases  
- **Database downtime** required during restore process
- **Resource usage** spike during restore operations
- **Network bandwidth** consumption for backup file processing

## 🔗 Related Documentation

- [📋 Main Project README](../../../README.md)
- [💾 Database Helm Chart](../README.md)
- [📊 Complete Disaster Recovery Guide](../../../DISASTER_RECOVERY_TESTING_GUIDE.md)
- [🎛️ ArgoCD Applications](../../../argocd-apps/README.md)

---

**🛠️ Manual disaster recovery operations for critical database restoration!** 🚀