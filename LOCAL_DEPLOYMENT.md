# Local Pi Cluster Deployment Guide

Since your Pi cluster is only accessible locally, here are several deployment options:

## 🚀 Deployment Options

### 1. **Manual Deployment** (Simplest)
Download and run deployment packages manually when you want to update.

### 2. **Polling Deployment** (Automated)
Run a service on your Pi that polls GitHub for changes every 5 minutes.

### 3. **Webhook Deployment** (Most Automated)
Run a webhook server on your local machine that receives GitHub webhooks.

## 📋 Option 1: Manual Deployment

### Quick Setup:
```bash
# On your local machine, after pushing to GitHub:
# 1. Go to GitHub Actions → Download deployment package
# 2. Transfer to Pi:
scp -i /Users/colin/pi/pi deployment-package.tar.gz pimaster@192.168.86.27:/tmp/

# 3. On Pi:
ssh -i /Users/colin/pi/pi pimaster@192.168.86.27
cd /tmp
tar -xzf deployment-package.tar.gz
cd deployment-package
./deploy-local.sh
```

### Automated Manual Deployment:
```bash
# Run this script on your Pi for manual deployments
chmod +x local-deployment/manual-deploy.sh
./local-deployment/manual-deploy.sh
```

## 🔄 Option 2: Polling Deployment (Recommended)

This runs a service on your Pi that automatically checks GitHub for changes.

### Setup:
```bash
# 1. Update repository details in the script
nano local-deployment/polling-deployer.py
# Change: REPO_OWNER = "your-github-username"
# Change: REPO_NAME = "your-repo-name"

# 2. Run setup script on Pi
chmod +x local-deployment/setup-polling-service.sh
./local-deployment/setup-polling-service.sh

# 3. Start the service
sudo systemctl start gitops-polling
sudo systemctl status gitops-polling
```

### Service Management:
```bash
# Start/Stop/Status
sudo systemctl start gitops-polling
sudo systemctl stop gitops-polling
sudo systemctl status gitops-polling

# View logs
sudo journalctl -u gitops-polling -f

# Enable auto-start on boot
sudo systemctl enable gitops-polling
```

## 🌐 Option 3: Webhook Deployment

This requires exposing a webhook server on your local network.

### Setup:
```bash
# 1. Install Python dependencies
pip3 install requests

# 2. Update repository details
nano local-deployment/webhook-server.py
# Change: 'your-repo-name' to your actual repository name

# 3. Run webhook server on your local machine
python3 local-deployment/webhook-server.py

# 4. Configure GitHub webhook:
# Go to your repo → Settings → Webhooks → Add webhook
# Payload URL: http://YOUR_LOCAL_IP:8080/webhook
# Content type: application/json
# Events: Just the push event
```

### Find Your Local IP:
```bash
# On macOS/Linux:
ifconfig | grep "inet " | grep -v 127.0.0.1

# Example: http://192.168.86.100:8080/webhook
```

## 🔧 Configuration Updates

### Update Repository Details:
You need to update these files with your actual GitHub repository details:

1. **Polling Deployer**: `local-deployment/polling-deployer.py`
   ```python
   REPO_OWNER = "cooksey14"
REPO_NAME = "homelab"
   ```

2. **Webhook Server**: `local-deployment/webhook-server.py`
   ```python
   'your-repo-name'  # Replace with actual repo name
   ```

3. **Manual Deploy**: `local-deployment/manual-deploy.sh`
   ```bash
   REPO_OWNER="cooksey14"
REPO_NAME="homelab"
   ```

## 📊 Monitoring and Troubleshooting

### Check Deployment Status:
```bash
# Check pods
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# Check service logs
sudo journalctl -u gitops-polling -f
```

### Common Issues:

1. **Permission Denied**:
   ```bash
   sudo chown -R pimaster:pimaster /opt/gitops-polling
   ```

2. **Python Dependencies**:
   ```bash
   sudo apt-get install python3-pip python3-requests
   ```

3. **Network Issues**:
   - Check GitHub API access: `curl https://api.github.com`
   - Check repository URL is correct
   - Verify branch name (usually 'main')

## 🚀 Recommended Setup

For your local Pi cluster, I recommend **Option 2 (Polling Deployment)**:

1. **Easy to set up** - One script sets everything up
2. **Automated** - Checks for changes every 5 minutes
3. **Reliable** - Runs as a systemd service
4. **No external dependencies** - Works with local-only cluster
5. **Logging** - Full logs for troubleshooting

### Quick Start:
```bash
# 1. Update repository details in polling-deployer.py
# 2. Run setup on Pi:
./local-deployment/setup-polling-service.sh

# 3. Start service:
sudo systemctl start gitops-polling

# 4. Check status:
sudo systemctl status gitops-polling
```

## 🔄 Workflow

1. **Push to GitHub** → GitHub Actions validates manifests
2. **Pi polls GitHub** → Detects new commit
3. **Pi downloads code** → Extracts and runs deployment
4. **Cluster updates** → New configuration applied
5. **ArgoCD syncs** → Ensures consistency

This gives you a complete GitOps workflow that works with your local-only Pi cluster! 🎉
