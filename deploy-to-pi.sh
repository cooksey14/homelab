#!/bin/bash

# Quick deployment script for Pi cluster
# This script deploys the current configuration directly to your Pi

set -e

echo "🚀 Deploying to Pi cluster..."

# Check if SSH key exists
if [ ! -f "/Users/colin/pi/pi" ]; then
    echo "❌ SSH key not found at /Users/colin/pi/pi"
    echo "Please update the SSH key path in this script"
    exit 1
fi

# Deploy to Pi
echo "📡 Connecting to Pi cluster..."
ssh -i /Users/colin/pi/pi pimaster@192.168.86.27 << 'EOF'
    echo "🔧 Setting up deployment on Pi..."
    
    # Create temporary directory
    mkdir -p /tmp/k3s-deploy
    cd /tmp/k3s-deploy
    
    # Download current repository (you'll need to update this URL)
    echo "📥 Downloading configuration..."
    curl -L https://github.com/cooksey14/homelab/archive/main.tar.gz | tar -xz
    
    # Find the extracted directory
    EXTRACTED_DIR=$(find . -name "*-main" -type d | head -1)
    if [ -z "$EXTRACTED_DIR" ]; then
        echo "❌ Could not find extracted directory"
        exit 1
    fi
    
    cd "$EXTRACTED_DIR/k3s"
    
    # Apply configurations
    echo "📁 Applying namespaces..."
    kubectl apply -f namespaces/ || echo "⚠️ Some namespaces may already exist"
    
    echo "🔐 Applying secrets..."
    kubectl apply -f secrets/
    
    echo "📊 Applying monitoring stack..."
    kubectl apply -f applications/monitoring/prometheus/
    
    echo "🍽️ Applying Mealie..."
    kubectl apply -f applications/mealie/
    
    echo "🔒 Applying cert-manager configurations..."
    kubectl apply -f certmanager/
    
    echo "🌐 Applying MetalLB configuration..."
    kubectl apply -f metalLB/metallb-config.yaml
    
    echo "✅ Deployment completed!"
    
    # Show status
    echo "📊 Pod Status:"
    kubectl get pods -A | grep -E "(prometheus|mealie|grafana|postgres)"
    
    # Clean up
    cd /
    rm -rf /tmp/k3s-deploy
EOF

echo "🎉 Deployment to Pi cluster completed!"
echo ""
echo "🌐 Access your applications:"
echo "Grafana: http://192.168.86.27:30180 (admin/admin)"
echo "Prometheus: http://192.168.86.27:30089"
echo "ArgoCD: https://argocd.cooklabs.net"
echo "Mealie: https://mealie.cooklabs.net"
