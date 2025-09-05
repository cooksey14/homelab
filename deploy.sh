#!/bin/bash

# K3s Cluster Deployment Script
# This script applies all configurations to your K3s cluster

set -e

echo "🚀 Starting K3s cluster configuration deployment..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please ensure kubectl is installed and configured."
    exit 1
fi

# Apply namespaces first
echo "📁 Applying namespaces..."
kubectl apply -f namespaces/

# Apply secrets
echo "🔐 Applying secrets..."
kubectl apply -f secrets/

# Apply monitoring stack
echo "📊 Applying monitoring stack..."
kubectl apply -f applications/monitoring/prometheus/

# Apply mealie
echo "🍽️ Applying Mealie..."
kubectl apply -f applications/mealie/

# Apply cert-manager configurations
echo "🔒 Applying cert-manager configurations..."
kubectl apply -f certmanager/

# Apply MetalLB configuration
echo "🌐 Applying MetalLB configuration..."
kubectl apply -f metalLB/metallb-config.yaml

echo "✅ Deployment completed successfully!"
echo ""
echo "🔍 Check the status of your applications:"
echo "kubectl get pods -A"
echo ""
echo "🌐 Access your applications:"
echo "Grafana: http://192.168.86.27:30180 (admin/admin)"
echo "Prometheus: http://192.168.86.27:30089"
echo "ArgoCD: https://argocd.cooklabs.net"
echo "Mealie: https://mealie.cooklabs.net"
