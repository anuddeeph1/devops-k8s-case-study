#!/bin/bash
echo "🚀 Starting HPA Auto-Scaling Demo"
echo "=================================="
echo ""

# Function to monitor HPA
monitor_hpa() {
    echo "📊 Current HPA Status:"
    kubectl get hpa web-server-hpa -n devops-case-study -o wide 2>/dev/null || echo "❌ HPA not found"
    
    echo ""
    echo "🏃 Web Server Pods:"
    kubectl get pods -n devops-case-study -l app.kubernetes.io/name=web-server --no-headers | wc -l | xargs echo "Total pods:"
    kubectl get pods -n devops-case-study -l app.kubernetes.io/name=web-server -o wide
    echo ""
}

# Show initial state
echo "📋 Initial State (Before Load Test):"
monitor_hpa

# Start load test
echo "🔥 Starting Load Test..."
kubectl exec deployment/load-tester -n devops-case-study -- /scripts/load-test.sh > /dev/null 2>&1 &
LOAD_TEST_PID=$!

# Monitor for 2 minutes
echo "⏱️  Monitoring HPA for 2 minutes..."
for i in {1..12}; do
    echo "=== Monitoring Cycle $i/12 ($(date)) ==="
    monitor_hpa
    sleep 10
done

echo "�� Stopping load test..."
kill $LOAD_TEST_PID 2>/dev/null || true

echo "✅ HPA Auto-Scaling Demo Complete!"
