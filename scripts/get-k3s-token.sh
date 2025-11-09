#!/bin/bash

# k3s Token Retrieval Script
# This script retrieves the k3s token from the master node
# Usage: ./get-k3s-token.sh [MASTER_IP]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MASTER_IP="${1:-10.0.1.10}"
K3S_TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get token via SSH
get_token_ssh() {
    print_status "Attempting to get token via SSH from $MASTER_IP..."
    
    if command -v ssh >/dev/null 2>&1; then
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$MASTER_IP "test -f $K3S_TOKEN_FILE" 2>/dev/null; then
            TOKEN=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$MASTER_IP "cat $K3S_TOKEN_FILE" 2>/dev/null)
            if [ -n "$TOKEN" ]; then
                print_success "Token retrieved successfully"
                echo "$TOKEN"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Function to get token via kubectl
get_token_kubectl() {
    print_status "Attempting to get token via kubectl..."
    
    if command -v kubectl >/dev/null 2>&1; then
        TOKEN=$(kubectl -n kube-system get secret k3s-token -o jsonpath='{.data.token}' | base64 -d 2>/dev/null)
        if [ -n "$TOKEN" ]; then
            print_success "Token retrieved via kubectl"
            echo "$TOKEN"
            return 0
        fi
    fi
    
    return 1
}

# Function to show manual instructions
show_manual_instructions() {
    print_error "Could not automatically retrieve token"
    echo
    print_status "Manual token retrieval instructions:"
    echo "1. SSH to the master node:"
    echo "   ssh root@$MASTER_IP"
    echo
    echo "2. Get the token:"
    echo "   sudo cat $K3S_TOKEN_FILE"
    echo
    echo "3. Copy the token and use it when joining worker nodes"
    echo
    print_status "Alternative method (if kubectl is available):"
    echo "kubectl -n kube-system get secret k3s-token -o jsonpath='{.data.token}' | base64 -d"
}

# Main execution
main() {
    print_status "Retrieving k3s token from master node ($MASTER_IP)..."
    
    # Try SSH first
    if get_token_ssh; then
        exit 0
    fi
    
    # Try kubectl
    if get_token_kubectl; then
        exit 0
    fi
    
    # Show manual instructions
    show_manual_instructions
    exit 1
}

# Run main function
main "$@"

