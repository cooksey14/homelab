#!/bin/bash

# k3s Worker Node Join Script
# This script joins a worker node to an existing k3s cluster
# Usage: ./join-worker-node.sh <MASTER_IP> [WORKER_IP]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MASTER_IP="${1:-192.168.86.27}"
WORKER_IP="${2:-$(hostname -I | awk '{print $1}')}"
K3S_TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
K3S_URL="https://${MASTER_IP}:6443"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if k3s is already installed
check_existing_k3s() {
    if command_exists k3s; then
        if systemctl is-active --quiet k3s; then
            print_warning "k3s is already running on this node"
            print_status "Current node status:"
            kubectl get nodes 2>/dev/null || print_error "Cannot connect to cluster"
            read -p "Do you want to reinstall k3s? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_status "Stopping and removing existing k3s installation..."
                sudo systemctl stop k3s
                sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
                print_success "Existing k3s installation removed"
            else
                print_status "Exiting without changes"
                exit 0
            fi
        else
            print_warning "k3s is installed but not running. Removing..."
            sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
        fi
    fi
}

# Function to get k3s token from master
get_k3s_token() {
    print_status "Getting k3s token from master node ($MASTER_IP)..."
    
    # Try to get token via SSH if possible
    if command_exists ssh; then
        print_status "Attempting to get token via SSH..."
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$MASTER_IP "test -f $K3S_TOKEN_FILE" 2>/dev/null; then
            K3S_TOKEN=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$MASTER_IP "cat $K3S_TOKEN_FILE" 2>/dev/null)
            if [ -n "$K3S_TOKEN" ]; then
                print_success "Token retrieved via SSH"
                return 0
            fi
        fi
    fi
    
    # Fallback: prompt user to manually enter token
    print_warning "Could not automatically retrieve token from master"
    print_status "Please run the following command on the master node to get the token:"
    echo "  sudo cat $K3S_TOKEN_FILE"
    echo
    read -p "Enter the k3s token: " K3S_TOKEN
    
    if [ -z "$K3S_TOKEN" ]; then
        print_error "No token provided. Exiting."
        exit 1
    fi
}

# Function to install k3s agent
install_k3s_agent() {
    print_status "Installing k3s agent on worker node..."
    print_status "Master IP: $MASTER_IP"
    print_status "Worker IP: $WORKER_IP"
    print_status "K3S URL: $K3S_URL"
    
    # Install k3s agent
    curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -s - agent \
        --node-ip="$WORKER_IP" \
        --kubelet-arg="node-ip=$WORKER_IP"
    
    print_success "k3s agent installed successfully"
}

# Function to verify node join
verify_join() {
    print_status "Verifying node join..."
    
    # Wait for node to be ready
    sleep 30
    
    # Check if we can connect to the cluster (this will only work if kubectl is available)
    if command_exists kubectl; then
        print_status "Checking node status..."
        kubectl get nodes
    else
        print_status "Node installed. Check from master node with: kubectl get nodes"
    fi
    
    # Check k3s agent status
    if systemctl is-active --quiet k3s; then
        print_success "k3s agent is running"
    else
        print_error "k3s agent is not running"
        exit 1
    fi
}

# Function to configure node for workloads
configure_workloads() {
    print_status "Configuring node for workloads..."
    
    # Add node labels for workload scheduling
    if command_exists kubectl; then
        NODE_NAME=$(hostname)
        kubectl label node "$NODE_NAME" node-role.kubernetes.io/worker=worker --overwrite
        kubectl label node "$NODE_NAME" workload-type=general --overwrite
        
        print_success "Node labeled for workload scheduling"
    else
        print_warning "kubectl not available. Node labeling will need to be done from master node"
        print_status "Run this command from master node:"
        echo "  kubectl label node $(hostname) node-role.kubernetes.io/worker=worker"
        echo "  kubectl label node $(hostname) workload-type=general"
    fi
}

# Function to install additional tools
install_tools() {
    print_status "Installing additional tools..."
    
    # Update package list
    sudo apt-get update
    
    # Install useful tools
    sudo apt-get install -y \
        curl \
        wget \
        git \
        htop \
        vim \
        net-tools \
        dnsutils \
        jq
    
    print_success "Additional tools installed"
}

# Function to configure networking
configure_networking() {
    print_status "Configuring networking..."
    
    # Ensure proper hostname
    HOSTNAME=$(hostname)
    echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null
    sudo hostnamectl set-hostname "$HOSTNAME"
    
    # Add master to hosts file if not present
    if ! grep -q "$MASTER_IP.*master" /etc/hosts; then
        echo "$MASTER_IP master" | sudo tee -a /etc/hosts
    fi
    
    print_success "Networking configured"
}

# Function to display node information
display_node_info() {
    print_success "Worker node setup completed successfully!"
    echo
    print_status "Node Information:"
    echo "  Hostname: $(hostname)"
    echo "  IP Address: $WORKER_IP"
    echo "  Master IP: $MASTER_IP"
    echo "  K3S URL: $K3S_URL"
    echo
    print_status "Next steps:"
    echo "  1. Verify node join from master: kubectl get nodes"
    echo "  2. Check node status: kubectl describe node $(hostname)"
    echo "  3. Deploy workloads to this node using node selectors"
    echo
    print_status "Useful commands:"
    echo "  Check k3s status: sudo systemctl status k3s"
    echo "  View k3s logs: sudo journalctl -u k3s -f"
    echo "  Restart k3s: sudo systemctl restart k3s"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <MASTER_IP> [WORKER_IP]"
    echo
    echo "Arguments:"
    echo "  MASTER_IP    IP address of the k3s master node (required)"
    echo "  WORKER_IP    IP address of this worker node (optional, auto-detected)"
    echo
    echo "Examples:"
    echo "  $0 192.168.86.27"
    echo "  $0 192.168.86.27 192.168.86.238"
    echo
    echo "Prerequisites:"
    echo "  - Worker node must be able to reach master node on port 6443"
    echo "  - Master node must have k3s token available"
    echo "  - Worker node should have unique hostname"
}

# Main execution
main() {
    # Check arguments
    if [ $# -lt 1 ]; then
        print_error "Master IP is required"
        show_usage
        exit 1
    fi
    
    # Validate IP addresses
    if ! validate_ip "$MASTER_IP"; then
        print_error "Invalid master IP address: $MASTER_IP"
        exit 1
    fi
    
    if ! validate_ip "$WORKER_IP"; then
        print_error "Invalid worker IP address: $WORKER_IP"
        exit 1
    fi
    
    print_status "Starting worker node join process..."
    print_status "Master IP: $MASTER_IP"
    print_status "Worker IP: $WORKER_IP"
    
    check_existing_k3s
    install_tools
    configure_networking
    get_k3s_token
    install_k3s_agent
    verify_join
    configure_workloads
    
    display_node_info
    
    print_success "Worker node join completed successfully!"
}

# Run main function
main "$@"
