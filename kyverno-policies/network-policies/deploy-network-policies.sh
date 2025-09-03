#!/bin/bash

# Deploy NetworkPolicies for DevOps Case Study
# This script manually deploys NetworkPolicies if ArgoCD is not used

set -e

echo "🛡️  Deploying NetworkPolicies for DevOps Case Study"
echo "=================================================="

# Check if namespace exists
if ! kubectl get namespace devops-case-study &> /dev/null; then
    echo "❌ Namespace 'devops-case-study' does not exist. Please create it first."
    echo "   kubectl create namespace devops-case-study"
    exit 1
fi

# Deploy NetworkPolicies
echo "📋 Deploying NetworkPolicies..."
kubectl apply -f network-policies.yaml

# Verify deployment
echo ""
echo "✅ Verification:"
kubectl get networkpolicies -n devops-case-study

echo ""
echo "🎯 NetworkPolicy Summary:"
echo "  ✅ Default Deny All - Baseline security"
echo "  ✅ Allow DNS Resolution - Essential for all pods"
echo "  ✅ Allow Web-to-Database - Core requirement (port 3306 only)"
echo "  ✅ Allow Web-Server Ingress - External access to web app"
echo "  ✅ Allow Monitoring Access - Health checks and metrics"
echo "  ✅ Allow Load Testing - HPA demonstration"
echo ""
echo "🛡️  Database Security: Only web-server pods can connect to database!"
echo "🔍 Test connectivity: kubectl exec -it <web-pod> -- nc -zv <db-service> 3306"
