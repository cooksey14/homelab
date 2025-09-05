#!/bin/bash

# Setup script for polling deployment service on Pi cluster
# This creates a systemd service that polls GitHub for changes

set -e

echo "🔧 Setting up polling deployment service..."

# Configuration
REPO_OWNER="cooksey14"
REPO_NAME="homelab"
SERVICE_NAME="gitops-polling"
SERVICE_USER="pimaster"
SERVICE_DIR="/opt/gitops-polling"

# Create service directory
sudo mkdir -p "$SERVICE_DIR"
sudo chown "$SERVICE_USER:$SERVICE_USER" "$SERVICE_DIR"

# Copy polling script
sudo cp polling-deployer.py "$SERVICE_DIR/"
sudo chmod +x "$SERVICE_DIR/polling-deployer.py"
sudo chown "$SERVICE_USER:$SERVICE_USER" "$SERVICE_DIR/polling-deployer.py"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-requests

# Create systemd service file
sudo tee "/etc/systemd/system/$SERVICE_NAME.service" > /dev/null << EOF
[Unit]
Description=GitOps Polling Deployer
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$SERVICE_DIR
ExecStart=/usr/bin/python3 $SERVICE_DIR/polling-deployer.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Environment variables
Environment=REPO_OWNER=$REPO_OWNER
Environment=REPO_NAME=$REPO_NAME

[Install]
WantedBy=multi-user.target
EOF

# Create log directory
sudo mkdir -p /var/log/gitops
sudo chown "$SERVICE_USER:$SERVICE_USER" /var/log/gitops

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

echo "✅ Polling service setup completed!"
echo ""
echo "📋 Service management commands:"
echo "  Start:   sudo systemctl start $SERVICE_NAME"
echo "  Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  Status:  sudo systemctl status $SERVICE_NAME"
echo "  Logs:    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "🔧 To start the service:"
echo "  sudo systemctl start $SERVICE_NAME"
echo ""
echo "📝 Don't forget to update the repository name in:"
echo "  - $SERVICE_DIR/polling-deployer.py"
echo "  - /etc/systemd/system/$SERVICE_NAME.service"
