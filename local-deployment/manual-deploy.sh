#!/bin/bash

# Manual deployment script for local Pi cluster
# This script can be run manually or via cron

set -e

# Configuration
REPO_OWNER="cooksey14"
REPO_NAME="homelab"
BRANCH="main"
TEMP_DIR="/tmp/gitops-manual-deploy"
LOG_FILE="/var/log/manual-deploy.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting manual deployment..."

# Create temporary directory
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download latest code
log "📥 Downloading latest code from GitHub..."
curl -L "https://github.com/$REPO_OWNER/$REPO_NAME/archive/$BRANCH.tar.gz" | tar -xz

# Find extracted directory
EXTRACTED_DIR=$(find . -name "${REPO_NAME}-*" -type d | head -1)
if [ -z "$EXTRACTED_DIR" ]; then
    log "❌ Could not find extracted repository directory"
    exit 1
fi

log "📁 Found extracted directory: $EXTRACTED_DIR"

# Navigate to k3s directory
K3S_DIR="$EXTRACTED_DIR/k3s"
if [ ! -d "$K3S_DIR" ]; then
    log "❌ K3s directory not found: $K3S_DIR"
    exit 1
fi

cd "$K3S_DIR"

# Run deployment
log "🔧 Running deployment script..."
if [ -f "./deploy.sh" ]; then
    ./deploy.sh
else
    log "❌ Deploy script not found"
    exit 1
fi

# Clean up
log "🧹 Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"

log "✅ Manual deployment completed successfully!"

# Show cluster status
log "📊 Cluster Status:"
kubectl get pods -A | grep -E "(prometheus|mealie|grafana|postgres)" | tee -a "$LOG_FILE"
