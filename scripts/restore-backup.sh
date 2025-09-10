#!/bin/bash
# Database Restore Script
# DevOps Case Study - Database Operations

set -e

NAMESPACE="devops-case-study"
RESTORE_JOB_NAME="database-restore-$(date +%Y%m%d-%H%M%S)"
BACKUP_VOLUME="mysql-backup-pvc"

echo "🔄 Database Restore from Latest Backup"
echo "======================================"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Namespace $NAMESPACE not found!"
    exit 1
fi

# Check if backup PVC exists
if ! kubectl get pvc "$BACKUP_VOLUME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Backup PVC $BACKUP_VOLUME not found in namespace $NAMESPACE!"
    echo "💡 Make sure backup system is deployed and has created backups"
    exit 1
fi

# Check if database service exists
if ! kubectl get service mysql-service -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ MySQL service not found in namespace $NAMESPACE!"
    exit 1
fi

echo "📋 Backup Information:"
echo "======================"

# Create temporary pod to list backup files
echo "🔍 Scanning for available backups..."

TEMP_POD="backup-scanner-$(date +%s)"
kubectl run "$TEMP_POD" \
    --image=busybox:1.35 \
    --restart=Never \
    --rm -i \
    --namespace="$NAMESPACE" \
    --overrides='{
        "spec": {
            "containers": [{
                "name": "scanner",
                "image": "busybox:1.35",
                "command": ["sh", "-c", "echo \"📁 Available backups:\" && ls -la /backups/ && echo \"\" && echo \"🕒 Latest backup:\" && ls -t /backups/*.sql.gz 2>/dev/null | head -1 || echo \"No .sql.gz backups found\""],
                "volumeMounts": [{
                    "name": "backup-storage",
                    "mountPath": "/backups"
                }]
            }],
            "volumes": [{
                "name": "backup-storage",
                "persistentVolumeClaim": {
                    "claimName": "'$BACKUP_VOLUME'"
                }
            }]
        }
    }' || {
    echo "❌ Failed to scan backup files"
    exit 1
}

echo ""
echo "⚠️  **WARNING: This will REPLACE all data in the database!**"
echo "🔄 This action is IRREVERSIBLE!"
echo ""

# Confirmation prompt
read -p "🤔 Are you sure you want to restore from the latest backup? (yes/NO): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Restore cancelled by user"
    exit 1
fi

echo ""
echo "📋 Creating database restore job..."
echo "🔧 Job Name: $RESTORE_JOB_NAME"
echo "📅 Timestamp: $(date)"
echo ""

# Create restore job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $RESTORE_JOB_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: database
    app.kubernetes.io/component: backup-job
    app.kubernetes.io/instance: devops-database
    operation: restore
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: database
        app.kubernetes.io/component: backup-job
        app.kubernetes.io/instance: devops-database
        operation: restore
    spec:
      restartPolicy: Never
      containers:
      - name: mysql-restore
        image: mysql:8.0
        command:
        - /bin/bash
        - -c
        - |
          echo "🔄 Starting MySQL database restore..."
          echo "📍 Target: mysql-service:3306"
          echo "💾 Database: \$MYSQL_DATABASE"
          echo ""
          
          # Find latest backup
          LATEST_BACKUP=\$(ls -t /backups/*.sql.gz 2>/dev/null | head -1)
          
          if [ -z "\$LATEST_BACKUP" ]; then
            echo "❌ No backup files found in /backups/"
            ls -la /backups/
            exit 1
          fi
          
          echo "📦 Latest backup found: \$(basename \$LATEST_BACKUP)"
          echo "📊 Backup size: \$(du -h \$LATEST_BACKUP | cut -f1)"
          echo ""
          
          # Test database connection
          echo "📍 Testing database connectivity..."
          mysql -h mysql-service -u root -p\$MYSQL_ROOT_PASSWORD -e "SELECT 1;" || {
            echo "❌ Cannot connect to database"
            exit 1
          }
          echo "✅ Database connection successful"
          echo ""
          
          # Drop and recreate database (WARNING: This removes all data!)
          echo "⚠️  Dropping existing database: \$MYSQL_DATABASE"
          mysql -h mysql-service -u root -p\$MYSQL_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS \$MYSQL_DATABASE;"
          
          echo "📦 Creating fresh database: \$MYSQL_DATABASE"
          mysql -h mysql-service -u root -p\$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE \$MYSQL_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
          
          # Restore from backup
          echo "🔄 Restoring database from backup..."
          echo "📂 Extracting: \$(basename \$LATEST_BACKUP)"
          
          gunzip -c "\$LATEST_BACKUP" | mysql -h mysql-service -u root -p\$MYSQL_ROOT_PASSWORD \$MYSQL_DATABASE
          
          if [ \$? -eq 0 ]; then
            echo ""
            echo "✅ **DATABASE RESTORE COMPLETED SUCCESSFULLY!**"
            echo ""
            echo "📊 Restore Summary:"
            echo "  📦 Backup File: \$(basename \$LATEST_BACKUP)"
            echo "  📅 Restore Date: \$(date)"
            echo "  💾 Target Database: \$MYSQL_DATABASE"
            echo ""
            
            # Verify restore
            echo "🔍 Verifying restored data..."
            TABLE_COUNT=\$(mysql -h mysql-service -u root -p\$MYSQL_ROOT_PASSWORD \$MYSQL_DATABASE -e "SHOW TABLES;" | wc -l)
            echo "  📊 Tables restored: \$((TABLE_COUNT - 1))"
            
            echo ""
            echo "🎉 Database restore completed successfully!"
          else
            echo ""
            echo "❌ Database restore failed!"
            exit 1
          fi
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        - name: MYSQL_DATABASE
          value: "testdb"
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 200m
            memory: 512Mi
        volumeMounts:
        - name: backup-storage
          mountPath: /backups
          readOnly: true
      volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: $BACKUP_VOLUME
EOF

if [ $? -eq 0 ]; then
    echo "✅ Restore job created successfully!"
else
    echo "❌ Failed to create restore job"
    exit 1
fi

echo ""
echo "⏳ Monitoring restore progress..."
echo "================================"

# Wait for job to start
echo "📍 Waiting for restore pod to start..."
sleep 5

# Get the restore pod
RESTORE_POD=$(kubectl get pods -n "$NAMESPACE" -l job-name="$RESTORE_JOB_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$RESTORE_POD" ]; then
    echo "❌ Could not find restore pod"
    kubectl get jobs -n "$NAMESPACE" | grep "$RESTORE_JOB_NAME" || echo "Job not found"
    exit 1
fi

echo "✅ Restore pod created: $RESTORE_POD"

# Monitor job progress
echo "📊 Job Status:"
kubectl get job "$RESTORE_JOB_NAME" -n "$NAMESPACE" -o wide

echo ""
echo "📋 Following restore logs (Press Ctrl+C to stop following, restore will continue):"
echo "=================================================================================="

# Follow logs with timeout
timeout 600s kubectl logs -f pod/"$RESTORE_POD" -n "$NAMESPACE" 2>/dev/null || {
    echo "⏰ Log following timed out or interrupted, checking final status..."
}

echo ""
echo "📊 Final Restore Status:"
echo "======================="

# Check final job status
JOB_STATUS=$(kubectl get job "$RESTORE_JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")

if [ "$JOB_STATUS" = "True" ]; then
    echo "✅ **DATABASE RESTORE COMPLETED SUCCESSFULLY!**"
    
    # Get restore completion logs
    echo ""
    echo "📋 Final restore logs:"
    kubectl logs pod/"$RESTORE_POD" -n "$NAMESPACE" --tail=10
    
    echo ""
    echo "📊 Job Summary:"
    kubectl get job "$RESTORE_JOB_NAME" -n "$NAMESPACE"
    
    echo ""
    echo "🔍 Database Verification:"
    echo "To verify the restored database, run:"
    echo "kubectl exec -n $NAMESPACE deployment/mysql-0 -- mysql -u root -p\$MYSQL_ROOT_PASSWORD -e \"USE testdb; SHOW TABLES;\""
    
elif [ "$(kubectl get job "$RESTORE_JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)" = "True" ]; then
    echo "❌ **DATABASE RESTORE FAILED!**"
    
    echo ""
    echo "📋 Error logs:"
    kubectl logs pod/"$RESTORE_POD" -n "$NAMESPACE" --tail=20
    
    echo ""
    echo "🔍 Debugging information:"
    kubectl describe job "$RESTORE_JOB_NAME" -n "$NAMESPACE"
    
else
    echo "⏳ **RESTORE STILL RUNNING**"
    
    echo ""
    echo "📋 Current status:"
    kubectl get job "$RESTORE_JOB_NAME" -n "$NAMESPACE"
    kubectl get pod "$RESTORE_POD" -n "$NAMESPACE"
    
    echo ""
    echo "🔍 To continue monitoring:"
    echo "kubectl logs -f pod/$RESTORE_POD -n $NAMESPACE"
fi

echo ""
echo "🧹 Cleanup Command (run after verification):"
echo "kubectl delete job $RESTORE_JOB_NAME -n $NAMESPACE"

echo ""
echo "✅ Database restore process completed!"
