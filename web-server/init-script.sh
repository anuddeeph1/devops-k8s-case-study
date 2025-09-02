#!/bin/bash

# Init container script to populate HTML template with dynamic values
set -e

echo "Starting init container to prepare web content..."

# Get the Pod IP
POD_IP=$(hostname -i)
echo "Pod IP: $POD_IP"

# Get the Pod Name from environment
POD_NAME=${POD_NAME:-"unknown"}
echo "Pod Name: $POD_NAME"

# Extract last 5 characters from pod name for serving-host
SERVING_HOST="Host-${POD_NAME: -5}"
echo "Serving Host: $SERVING_HOST"

# Get Node Name
NODE_NAME=${NODE_NAME:-"unknown"}
echo "Node Name: $NODE_NAME"

# Copy template to working directory and replace placeholders
cp /templates/index.html.template /shared/index.html

# Replace placeholders in the HTML file
sed -i "s/POD_IP_PLACEHOLDER/$POD_IP/g" /shared/index.html
sed -i "s/SERVING_HOST_PLACEHOLDER/$SERVING_HOST/g" /shared/index.html
sed -i "s/POD_NAME_PLACEHOLDER/$POD_NAME/g" /shared/index.html
sed -i "s/NODE_NAME_PLACEHOLDER/$NODE_NAME/g" /shared/index.html

echo "HTML template prepared successfully!"
echo "Content preview:"
head -n 20 /shared/index.html

# Create a simple status file for health checks
echo "Init completed at $(date)" > /shared/init-status.txt
