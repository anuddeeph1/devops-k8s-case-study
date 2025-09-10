#!/bin/bash
# Apply backup network policies to enable database backup connectivity
# DevOps Case Study - Network Policy Deployment

set -e

NAMESPACE="devops-case-study"

echo "🛡️ Applying Backup Network Policies"
echo "===================================="
echo ""

# Check if Kyverno is running
echo "📋 Checking Kyverno status..."
if ! kubectl get pods -n kyverno | grep -q "Running"; then
    echo "❌ Kyverno is not running! Network policies require Kyverno to be installed."
    echo "💡 Deploy Kyverno first: helm upgrade --install kyverno ./helm-charts/kyverno/"
    exit 1
fi

echo "✅ Kyverno is running"
echo ""

# Apply network policies
echo "📦 Deploying network policies with backup support..."
if helm upgrade --install network-policies ./helm-charts/network-policies/ \
    --namespace argocd \
    --create-namespace \
    --timeout 300s \
    --wait; then
    echo "✅ Network policies deployed successfully!"
else
    echo "❌ Failed to deploy network policies"
    exit 1
fi

echo ""
echo "⏳ Waiting for Kyverno to process new policies..."
sleep 10

# Check if the new backup policies are created
echo "🔍 Checking for backup-related ClusterPolicies..."
BACKUP_POLICIES=$(kubectl get clusterpolicies | grep -i backup | wc -l)
if [ "$BACKUP_POLICIES" -gt 0 ]; then
    echo "✅ Found $BACKUP_POLICIES backup-related ClusterPolicies"
    kubectl get clusterpolicies | grep -i backup
else
    echo "⚠️  No backup ClusterPolicies found yet. They may still be processing..."
fi

echo ""
echo "🔍 Checking existing pods to trigger NetworkPolicy generation..."

# Get database pods to check if they exist
DB_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=database --no-headers | wc -l)
if [ "$DB_PODS" -gt 0 ]; then
    echo "✅ Found $DB_PODS database pods"
    
    # Force policy generation by restarting database pods (optional)
    read -p "🔄 Restart database pods to trigger network policy generation? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Restarting database pods..."
        kubectl rollout restart deployment/mysql -n "$NAMESPACE" || \
        kubectl rollout restart statefulset/mysql -n "$NAMESPACE" || \
        echo "⚠️  Could not restart database - it may be a different resource type"
    fi
else
    echo "⚠️  No database pods found in namespace $NAMESPACE"
fi

echo ""
echo "🧪 Testing backup connectivity..."
if [ -f "scripts/test-backup-connectivity.sh" ]; then
    echo "📋 Running connectivity test..."
    ./scripts/test-backup-connectivity.sh
else
    echo "⚠️  Test script not found. Manual testing recommended."
fi

echo ""
echo "📋 Manual testing commands:"
echo "=========================="
echo ""
echo "# Test backup job creation:"
echo "kubectl create job --from=cronjob/devops-database-backup-cronjob manual-backup-test -n $NAMESPACE"
echo ""
echo "# Check job status:"
echo "kubectl get jobs -n $NAMESPACE | grep backup"
echo ""
echo "# View backup job logs:"
echo "kubectl logs job/manual-backup-test -n $NAMESPACE"
echo ""
echo "# Check generated NetworkPolicies:"
echo "kubectl get networkpolicies -n $NAMESPACE"
echo ""
echo "# Clean up test job:"
echo "kubectl delete job manual-backup-test -n $NAMESPACE --ignore-not-found"

echo ""
echo "🎉 Backup network policy deployment completed!"
