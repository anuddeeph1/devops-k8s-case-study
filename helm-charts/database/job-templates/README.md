# 🚨 On-Demand Database Job Templates

These job templates are **not deployed automatically** by ArgoCD. They are **on-demand templates** for disaster recovery operations.

## 📋 Available Templates

### 1. **Restore Job** (`backup-restore-job.yaml`)
Restores MySQL database from the latest backup or a specific backup file.

### 2. **Verify Job** (`backup-verify-job.yaml`) 
Verifies database health and connectivity.

## 🚀 Usage

### **Generate and Apply Restore Job**
```bash
# Generate the restore job YAML
helm template devops-database . -f values.yaml -s templates/job-templates/backup-restore-job.yaml > restore-job.yaml

# Apply the restore job
kubectl apply -f restore-job.yaml

# Monitor restore progress
kubectl logs job/devops-database-restore-job -n devops-case-study -f
```

### **Generate and Apply Verify Job**
```bash
# Generate the verify job YAML
helm template devops-database . -f values.yaml -s templates/job-templates/backup-verify-job.yaml > verify-job.yaml

# Apply the verify job
kubectl apply -f verify-job.yaml

# Check verification results
kubectl logs job/devops-database-verify-job -n devops-case-study
```

### **Quick One-Liners**
```bash
# Quick restore (latest backup)
helm template devops-database . -f values.yaml -s templates/job-templates/backup-restore-job.yaml | kubectl apply -f -

# Quick verify
helm template devops-database . -f values.yaml -s templates/job-templates/backup-verify-job.yaml | kubectl apply -f -

# Clean up jobs after use
kubectl delete job devops-database-restore-job devops-database-verify-job -n devops-case-study --ignore-not-found
```

## 🔄 Automated Components (Always Running)

The following components are **automatically managed** by the database Helm chart:

✅ **Backup CronJob**: `devops-database-backup-cronjob` (every 6 hours)  
✅ **Backup Scripts**: `devops-database-backup-script` ConfigMap  
✅ **Backup Storage**: `devops-database-backup-pvc` (5Gi)  

## 🎯 Integration

These templates are part of the **GitOps-managed disaster recovery solution** integrated into the database microservice Helm chart.
