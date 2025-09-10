# Database Backup & Restore Operations

This document describes the backup and restore scripts for the MySQL database in the DevOps Case Study project.

## 🗄️ Manual Backup

### Script: `manual-backup.sh`

Creates a manual database backup job and monitors its progress.

```bash
./scripts/manual-backup.sh
```

**What it does:**
- ✅ Creates a manual backup job from the CronJob template
- ✅ Monitors backup progress with real-time logs
- ✅ Reports backup completion status
- ✅ Shows NetworkPolicy generation (backup security)
- ✅ Provides cleanup commands

**Output:**
- Compressed backup file: `mysql_backup_YYYYMMDD_HHMMSS.sql.gz`
- Stored in persistent volume at `/backups/`
- Automatic cleanup of old backups (7+ days)

---

## 🔄 Database Restore

### Script: `restore-backup.sh`

Restores the latest backup to the MySQL database.

```bash
./scripts/restore-backup.sh
```

**What it does:**
- ✅ Scans for available backups
- ✅ Shows latest backup information
- ⚠️ **ASKS FOR CONFIRMATION** (destructive operation!)
- ✅ Creates restore job with proper NetworkPolicies
- ✅ Drops and recreates target database
- ✅ Restores from latest compressed backup
- ✅ Verifies restore completion

**⚠️ WARNING:** This script will **REPLACE ALL DATA** in the target database!

---

## 📋 Usage Examples

### Take Manual Backup
```bash
# Simple manual backup
./scripts/manual-backup.sh

# Will create job like: manual-backup-20250910-123045
# Monitors progress and shows completion status
```

### Restore Latest Backup
```bash
# Restore from latest backup (DESTRUCTIVE!)
./scripts/restore-backup.sh

# Will prompt for confirmation before proceeding
# Shows available backups before restore
```

### Verify Database After Restore
```bash
# Check restored tables
kubectl exec -n devops-case-study mysql-0 -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "USE testdb; SHOW TABLES;"

# Check specific data
kubectl exec -n devops-case-study mysql-0 -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "USE testdb; SELECT COUNT(*) FROM your_table;"
```

---

## 🛡️ Security Features

Both scripts automatically use the **backup NetworkPolicies**:

- ✅ **Backup Egress**: Allows backup pods to connect to database + DNS
- ✅ **Database Ingress**: Allows database to accept backup connections
- ✅ **Automatic Cleanup**: NetworkPolicies deleted when jobs complete
- ✅ **Zero-Trust**: All other traffic remains blocked

**NetworkPolicies Generated:**
- `backup-egress-{job-name}` - Pod can access database
- `backup-ingress-{job-name}` - Database accepts backup connections

---

## 🔧 Troubleshooting

### Backup Issues

**Problem**: Backup job fails to connect to database
```bash
# Check NetworkPolicies
kubectl get networkpolicies -n devops-case-study | grep backup

# Check backup pod logs
kubectl logs -n devops-case-study -l job-name=manual-backup-XXXXXX
```

**Problem**: No backup files found
```bash
# Check backup PVC contents
kubectl run temp-checker --rm -i --image=busybox:1.35 \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "checker",
        "image": "busybox:1.35", 
        "command": ["ls", "-la", "/backups"],
        "volumeMounts": [{"name": "backup-storage", "mountPath": "/backups"}]
      }],
      "volumes": [{"name": "backup-storage", "persistentVolumeClaim": {"claimName": "mysql-backup-pvc"}}]
    }
  }'
```

### Restore Issues

**Problem**: Restore fails with connection error
```bash
# Verify MySQL service is running
kubectl get pods -n devops-case-study -l app.kubernetes.io/name=database

# Check MySQL service
kubectl get service mysql-service -n devops-case-study
```

**Problem**: Permission denied during restore
```bash
# Check MySQL root credentials
kubectl get secret mysql-secret -n devops-case-study -o yaml
```

---

## 📊 Monitoring & Cleanup

### Monitor Jobs
```bash
# Watch backup/restore jobs
kubectl get jobs -n devops-case-study --watch

# Follow job logs
kubectl logs -f -n devops-case-study job/manual-backup-XXXXXX
```

### Cleanup Old Jobs
```bash
# List all backup/restore jobs
kubectl get jobs -n devops-case-study | grep -E "(backup|restore)"

# Delete specific job
kubectl delete job manual-backup-XXXXXX -n devops-case-study

# Delete all completed jobs older than 1 day
kubectl delete jobs -n devops-case-study --field-selector=status.successful=1 --all
```

---

## 🚀 Automation

### Schedule Additional Backups
The main backup runs every 6 hours via CronJob. For more frequent backups:

```bash
# Manual backup every hour during business hours
# Add to crontab: 0 8-17 * * * /path/to/manual-backup.sh
```

### Integration with CI/CD
```bash
# Before deployment, create backup
./scripts/manual-backup.sh

# After deployment, verify database
kubectl exec -n devops-case-study mysql-0 -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "USE testdb; SELECT COUNT(*) FROM users;"
```

---

**💡 Pro Tips:**
- Always test restores in non-production environments first
- Keep multiple backup copies for disaster recovery
- Monitor backup job completion in your alerting system
- Document your restore procedures for emergency situations
