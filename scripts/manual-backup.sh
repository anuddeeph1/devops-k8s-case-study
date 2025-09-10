#!/bin/bash
# Manual Database Backup Script
# DevOps Case Study - Database Operations

set -e

NAMESPACE="devops-case-study"
CRONJOB_NAME="devops-database-backup-cronjob"
JOB_NAME="manual-backup-$(date +%Y%m%d-%H%M%S)"

echo "🗄️  Manual Database Backup"
echo "=========================="
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Namespace $NAMESPACE not found!"
    exit 1
fi

# Check if CronJob exists
if ! kubectl get cronjob "$CRONJOB_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ CronJob $CRONJOB_NAME not found in namespace $NAMESPACE!"
    echo "💡 Make sure the database application is deployed"
    exit 1
fi

echo "📋 Creating manual backup job from CronJob..."
echo "🔧 Job Name: $JOB_NAME"
echo "📅 Timestamp: $(date)"
echo ""

# Create manual job from CronJob
if kubectl create job "$JOB_NAME" --from=cronjob/"$CRONJOB_NAME" -n "$NAMESPACE"; then
    echo "✅ Backup job created successfully!"
else
    echo "❌ Failed to create backup job"
    exit 1
fi

echo ""
echo "⏳ Monitoring backup progress..."
echo "================================"

# Wait for job to start
echo "📍 Waiting for backup pod to start..."
sleep 5

# Get the backup pod
BACKUP_POD=$(kubectl get pods -n "$NAMESPACE" -l job-name="$JOB_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$BACKUP_POD" ]; then
    echo "❌ Could not find backup pod"
    kubectl get jobs -n "$NAMESPACE" | grep "$JOB_NAME" || echo "Job not found"
    exit 1
fi

echo "✅ Backup pod created: $BACKUP_POD"

# Monitor job progress
echo "📊 Job Status:"
kubectl get job "$JOB_NAME" -n "$NAMESPACE" -o wide

echo ""
echo "📋 Following backup logs (Press Ctrl+C to stop following, backup will continue):"
echo "==============================================================================="

# Follow logs with timeout
timeout 600s kubectl logs -f pod/"$BACKUP_POD" -n "$NAMESPACE" 2>/dev/null || {
    echo "⏰ Log following timed out or interrupted, checking final status..."
}

echo ""
echo "📊 Final Backup Status:"
echo "======================"

# Check final job status
JOB_STATUS=$(kubectl get job "$JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")

if [ "$JOB_STATUS" = "True" ]; then
    echo "✅ **BACKUP COMPLETED SUCCESSFULLY!**"
    
    # Get backup completion logs
    echo ""
    echo "📋 Final backup logs:"
    kubectl logs pod/"$BACKUP_POD" -n "$NAMESPACE" --tail=20
    
    echo ""
    echo "📊 Job Summary:"
    kubectl get job "$JOB_NAME" -n "$NAMESPACE"
    
    echo ""
    echo "📁 To view backup files, run:"
    echo "kubectl exec -n $NAMESPACE $BACKUP_POD -- ls -la /backups/"
    
    echo ""
    echo "🧹 Cleanup Command (run after verification):"
    echo "kubectl delete job $JOB_NAME -n $NAMESPACE"
    
elif [ "$(kubectl get job "$JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)" = "True" ]; then
    echo "❌ **BACKUP FAILED!**"
    
    echo ""
    echo "📋 Error logs:"
    kubectl logs pod/"$BACKUP_POD" -n "$NAMESPACE" --tail=20
    
    echo ""
    echo "🔍 Debugging information:"
    kubectl describe job "$JOB_NAME" -n "$NAMESPACE"
    kubectl describe pod "$BACKUP_POD" -n "$NAMESPACE"
    
else
    echo "⏳ **BACKUP STILL RUNNING**"
    
    echo ""
    echo "📋 Current status:"
    kubectl get job "$JOB_NAME" -n "$NAMESPACE"
    kubectl get pod "$BACKUP_POD" -n "$NAMESPACE"
    
    echo ""
    echo "🔍 To continue monitoring:"
    echo "kubectl logs -f pod/$BACKUP_POD -n $NAMESPACE"
    echo "kubectl get job $JOB_NAME -n $NAMESPACE --watch"
fi

echo ""
echo "🔍 NetworkPolicy Status (should see backup policies):"
kubectl get networkpolicies -n "$NAMESPACE" | grep backup || echo "No backup NetworkPolicies found"

echo ""
echo "✅ Manual backup process completed!"
