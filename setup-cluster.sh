#!/bin/bash

# DevOps Case Study - Cluster Setup Script
echo "Setting up DevOps Case Study environment..."

# Check if KIND is installed
if ! command -v kind &> /dev/null; then
    echo "KIND not found. Please install KIND first:"
    echo "brew install kind"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Please install kubectl first:"
    echo "brew install kubectl"
    exit 1
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "Helm not found. Please install Helm first:"
    echo "brew install helm"
    exit 1
fi

# Check Docker Hub login
echo "Checking Docker Hub authentication..."
if ! docker info | grep -q "Username:"; then
    echo "⚠️  Please ensure you're logged in to Docker Hub:"
    echo "docker login"
fi

# Create KIND cluster
echo "Creating KIND cluster..."
kind create cluster --config kind-cluster-config.yaml

# Note: Using Docker Hub instead of local registry
echo "Using Docker Hub registry: anuddeeph"

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "Cluster setup complete!"
echo "Cluster info:"
kubectl cluster-info

echo ""
echo "To use this cluster:"
echo "kubectl config use-context kind-devops-case-study"
