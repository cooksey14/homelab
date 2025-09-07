#!/bin/bash
# Wazuh Host Agent Installation Script for Raspberry Pi
# Run this script on each Raspberry Pi node (master + workers)

set -e

# Configuration
WAZUH_MANAGER_IP="192.168.86.101"  # Your LoadBalancer IP
WAZUH_MANAGER_PORT="1514"
WAZUH_REGISTRATION_PORT="1515"
WAZUH_REGISTRATION_PASSWORD="password"  # Change this!

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Wazuh Agent on Raspberry Pi...${NC}"

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt install -y curl apt-transport-https lsb-release gnupg

# Add Wazuh repository
echo -e "${YELLOW}Adding Wazuh repository...${NC}"
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && sudo chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee -a /etc/apt/sources.list.d/wazuh.list

# Update package list
sudo apt update

# Install Wazuh agent
echo -e "${YELLOW}Installing Wazuh agent...${NC}"
sudo WAZUH_MANAGER="$WAZUH_MANAGER_IP" WAZUH_MANAGER_PORT="$WAZUH_MANAGER_PORT" WAZUH_PROTOCOL="tcp" WAZUH_REGISTRATION_SERVER="$WAZUH_MANAGER_IP" WAZUH_REGISTRATION_PORT="$WAZUH_REGISTRATION_PORT" WAZUH_REGISTRATION_PASSWORD="$WAZUH_REGISTRATION_PASSWORD" WAZUH_KEEP_ALIVE_INTERVAL="60" WAZUH_TIME_RECONNECT="60" WAZUH_REGISTRATION_CA="/var/ossec/etc/rootca.pem" WAZUH_REGISTRATION_CERTIFICATE="/var/ossec/etc/sslagent.pem" WAZUH_REGISTRATION_KEY="/var/ossec/etc/sslagent.key" WAZUH_AGENT_NAME="$(hostname)" WAZUH_AGENT_GROUP="default" apt install wazuh-agent

# Start and enable Wazuh agent
echo -e "${YELLOW}Starting Wazuh agent service...${NC}"
sudo systemctl start wazuh-agent
sudo systemctl enable wazuh-agent

# Check status
echo -e "${YELLOW}Checking Wazuh agent status...${NC}"
sudo systemctl status wazuh-agent --no-pager

echo -e "${GREEN}Wazuh agent installation completed!${NC}"
echo -e "${YELLOW}Agent name: $(hostname)${NC}"
echo -e "${YELLOW}Manager: $WAZUH_MANAGER_IP:$WAZUH_MANAGER_PORT${NC}"
echo -e "${YELLOW}Registration: $WAZUH_MANAGER_IP:$WAZUH_REGISTRATION_PORT${NC}"

# Show logs
echo -e "${YELLOW}Recent agent logs:${NC}"
sudo tail -20 /var/ossec/logs/ossec.log
