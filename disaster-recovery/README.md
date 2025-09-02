# 🚨 MySQL Disaster Recovery Solution

## Overview

This document outlines the comprehensive disaster recovery (DR) strategy for the MySQL database in our DevOps case study environment.

## 📊 Recovery Objectives

### **RTO (Recovery Time Objective)**: 30 minutes
- Maximum time to restore service after a disaster

### **RPO (Recovery Point Objective)**: 6 hours  
- Maximum data loss acceptable (backup frequency)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MySQL Pod     │    │  Backup CronJob │    │ Backup Storage  │
│                 │────│                 │────│                 │
│ Primary DB      │    │ Every 6 hours   │    │ PV: 20Gi       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data Loss     │    │  Backup Files   │    │ Restore Jobs    │
│ ≤ 6 hours       │    │ Compressed SQL  │    │ On-Demand       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔄 Backup Strategy

### **Automated Backups**
- **Frequency**: Every 6 hours (00:00, 06:00, 12:00, 18:00 UTC)
- **Type**: Full database dump (mysqldump)
- **Compression**: Gzip compression to save storage
- **Retention**: 7 days (adjustable via `RETENTION_DAYS`)
- **Storage**: Persistent volume with 20Gi capacity

### **Backup Features**
- ✅ **Single Transaction**: Ensures data consistency
- ✅ **All Databases**: Complete backup including system databases
- ✅ **Routines & Triggers**: Includes stored procedures and triggers
- ✅ **Master Data**: Contains binary log coordinates for point-in-time recovery
- ✅ **Automated Cleanup**: Removes old backups based on retention policy
- ✅ **Logging**: Maintains backup and restore logs

## 🚀 Deployment

### **1. Deploy Disaster Recovery Infrastructure**

```bash
# Deploy all DR components
kubectl apply -f disaster-recovery/

# Verify deployment
kubectl get pvc,cronjob,configmap -n devops-case-study | grep -E "backup|restore"
```

### **2. Manual Backup (Test)**

```bash
# Create a manual backup job
kubectl create job --from=cronjob/mysql-backup-cronjob manual-backup-$(date +%s) -n devops-case-study

# Check backup logs
kubectl logs -l app=mysql-backup-job -n devops-case-study --tail=20
```

## 🔧 Operations

### **List Available Backups**

```bash
# Exec into backup pod to see files
kubectl run backup-browser --rm -it --image=mysql:8.0 --restart=Never -n devops-case-study \
  --overrides='{"spec":{"volumes":[{"name":"backup-vol","persistentVolumeClaim":{"claimName":"mysql-backup-pvc"}}],"containers":[{"name":"backup-browser","image":"mysql:8.0","command":["ls","-lah","/backups"],"volumeMounts":[{"name":"backup-vol","mountPath":"/backups"}]}]}}'
```

### **Restore from Latest Backup**

```bash
# Create restore job
kubectl apply -f disaster-recovery/mysql-restore-job.yaml

# Monitor restore progress
kubectl logs job/mysql-restore-job -n devops-case-study -f
```

### **Restore from Specific Backup**

```bash
# Edit restore job to specify backup file
kubectl patch job mysql-restore-job -n devops-case-study --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "BACKUP_FILE", "value": "mysql_backup_20250902_120000.sql.gz"}}]'
```

### **Verify Database Health**

```bash
# Run verification job
kubectl apply -f disaster-recovery/mysql-verify-job.yaml

# Check results
kubectl logs job/mysql-verify-job -n devops-case-study
```

## 🧪 Testing Procedures

### **1. Backup Test**

```bash
# 1. Create test data
kubectl exec -it deployment/mysql -n devops-case-study -- mysql -u root -proot123 -e "
CREATE DATABASE IF NOT EXISTS disaster_test;
USE disaster_test;
CREATE TABLE test_table (id INT PRIMARY KEY, data VARCHAR(100));
INSERT INTO test_table VALUES (1, 'test data before backup');
"

# 2. Force backup
kubectl create job --from=cronjob/mysql-backup-cronjob test-backup-$(date +%s) -n devops-case-study

# 3. Wait for backup completion and verify
kubectl wait --for=condition=complete job/test-backup-* -n devops-case-study --timeout=300s
```

### **2. Restore Test**

```bash
# 1. Create new test data (to simulate data loss)
kubectl exec -it deployment/mysql -n devops-case-study -- mysql -u root -proot123 -e "
USE disaster_test;
INSERT INTO test_table VALUES (2, 'data that will be lost');
DROP DATABASE disaster_test;
"

# 2. Perform restore
kubectl delete job mysql-restore-job -n devops-case-study --ignore-not-found
kubectl apply -f disaster-recovery/mysql-restore-job.yaml
kubectl wait --for=condition=complete job/mysql-restore-job -n devops-case-study --timeout=600s

# 3. Verify restore
kubectl exec -it deployment/mysql -n devops-case-study -- mysql -u root -proot123 -e "
USE disaster_test;
SELECT * FROM test_table;
"
# Should show only the data from before backup
```

### **3. Full Disaster Recovery Test**

```bash
# 1. Simulate complete database failure
kubectl delete deployment mysql -n devops-case-study

# 2. Simulate data loss
kubectl delete pvc mysql-pvc -n devops-case-study

# 3. Recreate database infrastructure
kubectl apply -f database/

# 4. Wait for database to be ready
kubectl wait --for=condition=available deployment/mysql -n devops-case-study --timeout=300s

# 5. Restore from backup
kubectl apply -f disaster-recovery/mysql-restore-job.yaml

# 6. Verify complete recovery
kubectl apply -f disaster-recovery/mysql-verify-job.yaml
```

## 📋 Monitoring and Alerts

### **Backup Monitoring**

```bash
# Check recent backup jobs
kubectl get jobs -n devops-case-study -l app=mysql-backup-job --sort-by=.status.startTime

# Check CronJob status
kubectl describe cronjob mysql-backup-cronjob -n devops-case-study

# View backup logs
kubectl get pods -n devops-case-study -l app=mysql-backup-job --sort-by=.status.startTime | tail -1 | awk '{print $1}' | xargs kubectl logs -n devops-case-study
```

### **Storage Monitoring**

```bash
# Check backup storage usage
kubectl exec -it deployment/mysql -n devops-case-study -- df -h | grep backups
```

## ⚠️ Troubleshooting

### **Common Issues**

| Issue | Cause | Solution |
|-------|-------|----------|
| Backup job fails | Insufficient permissions | Check RBAC and secrets |
| Storage full | Too many backups | Adjust `RETENTION_DAYS` |
| Restore hangs | Large backup file | Increase job timeout |
| Connection refused | MySQL not ready | Wait for MySQL pod readiness |

### **Recovery Scenarios**

| Scenario | Recovery Time | Data Loss | Actions |
|----------|---------------|-----------|---------|
| **Pod failure** | < 5 minutes | None | Kubernetes auto-restart |
| **PVC corruption** | 15-30 minutes | ≤ 6 hours | Restore from backup |
| **Complete cluster loss** | 30+ minutes | ≤ 6 hours | Rebuild + restore |
| **Backup corruption** | Variable | Up to 12 hours | Use older backup |

## 🔒 Security Considerations

- ✅ **Encrypted at Rest**: Backup files stored on encrypted PV
- ✅ **Access Control**: RBAC restricts backup access
- ✅ **Secret Management**: Database credentials via Kubernetes secrets
- ✅ **Network Policies**: Restrict backup job network access (if implemented)

## 📈 Performance Impact

- **Backup Duration**: ~2-5 minutes for typical databases
- **Storage Overhead**: ~30% of database size (compressed)
- **Network Impact**: Minimal (local PV storage)
- **Database Performance**: < 5% impact during backup (single transaction)

## 🔄 Continuous Improvement

### **Recommended Enhancements**

1. **External Storage**: Configure backups to cloud storage (S3, GCS)
2. **Encryption**: Encrypt backup files before storage
3. **Point-in-Time Recovery**: Implement binary log backup
4. **Multi-Region**: Replicate backups across regions
5. **Automated Testing**: Schedule regular restore tests
6. **Monitoring**: Integrate with Prometheus/AlertManager

## 📞 Emergency Contacts

- **Database Administrator**: [Your Contact Info]
- **DevOps Team**: [Team Contact Info]  
- **Escalation**: [Manager Contact Info]

## 📚 References

- [MySQL Backup Documentation](https://dev.mysql.com/doc/refman/8.0/en/backup-and-recovery.html)
- [Kubernetes Jobs Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJob Best Practices](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

---

**Last Updated**: $(date)  
**Version**: 1.0  
**Maintained By**: DevOps Case Study Team
