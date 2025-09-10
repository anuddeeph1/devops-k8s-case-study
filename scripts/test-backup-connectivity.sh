#!/bin/bash
# Test script to verify backup connectivity to database
# DevOps Case Study - Network Policy Testing

set -e

NAMESPACE="devops-case-study"
BACKUP_TEST_POD="backup-connectivity-test"

echo "🧪 Testing Backup Connectivity to Database"
echo "=========================================="
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Namespace $NAMESPACE not found!"
    exit 1
fi

# Check if database service exists
if ! kubectl get service mysql-service -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Database service mysql-service not found in namespace $NAMESPACE!"
    exit 1
fi

echo "📋 Testing backup pod connectivity to MySQL database..."
echo ""

# Create a temporary test pod that mimics a backup job
echo "🔧 Creating temporary backup test pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $BACKUP_TEST_POD
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: database
    app.kubernetes.io/component: backup-job
    test: connectivity
spec:
  restartPolicy: Never
  containers:
  - name: mysql-client
    image: mysql:8.0
    command:
    - /bin/bash
    - -c
    - |
      echo "🔍 Testing MySQL connectivity from backup pod..."
      
      # Test DNS resolution
      echo "📍 Testing DNS resolution for mysql-service..."
      if nslookup mysql-service; then
        echo "✅ DNS resolution successful"
      else
        echo "❌ DNS resolution failed"
        exit 1
      fi
      
      # Test port connectivity
      echo "📍 Testing port connectivity to mysql-service:3306..."
      if nc -z mysql-service 3306; then
        echo "✅ Port 3306 is reachable"
      else
        echo "❌ Port 3306 is not reachable"
        exit 1
      fi
      
      # Test MySQL authentication (using environment variables)
      echo "📍 Testing MySQL authentication..."
      mysql -h mysql-service -u root -p\$MYSQL_ROOT_PASSWORD -e "SELECT 1 as connection_test;" || {
        echo "⚠️  MySQL authentication test failed (expected if wrong credentials)"
        echo "🔍 But network connectivity is working!"
      }
      
      echo "🎉 Backup connectivity test completed successfully!"
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-secret
          key: mysql-root-password
EOF

echo "⏳ Waiting for test pod to start..."
kubectl wait --for=condition=Ready pod/$BACKUP_TEST_POD -n "$NAMESPACE" --timeout=60s || {
    echo "⚠️  Pod not ready within timeout, checking logs..."
}

echo ""
echo "📋 Test pod logs:"
echo "=================="
kubectl logs $BACKUP_TEST_POD -n "$NAMESPACE" || {
    echo "❌ Failed to get logs. Pod may not be running yet."
}

# Get final pod status
echo ""
echo "📊 Final pod status:"
kubectl get pod $BACKUP_TEST_POD -n "$NAMESPACE" -o wide

# Clean up test pod
echo ""
echo "🧹 Cleaning up test pod..."
kubectl delete pod $BACKUP_TEST_POD -n "$NAMESPACE" --ignore-not-found

echo ""
echo "🔍 Network Policy Status:"
echo "========================="
echo "Current NetworkPolicies in namespace $NAMESPACE:"
kubectl get networkpolicies -n "$NAMESPACE" | grep -E "(backup|database)" || echo "No backup/database specific policies found yet"

echo ""
echo "📝 CronJob Status:"
echo "=================="
kubectl get cronjobs -n "$NAMESPACE" | grep backup || echo "No backup cronjobs found"

echo ""
echo "✅ Backup connectivity test completed!"
echo ""
echo "📋 Next Steps:"
echo "- If connectivity failed, ensure network policies are deployed"
echo "- Run: helm upgrade --install network-policies ./helm-charts/network-policies/"
echo "- Check Kyverno policy status: kubectl get clusterpolicies | grep backup"
echo "- Test actual backup job: kubectl create job --from=cronjob/devops-database-backup-cronjob manual-backup-test -n $NAMESPACE"
