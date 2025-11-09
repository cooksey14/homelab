#!/bin/bash

# Quick MetalLB Fix Script
# This script quickly fixes common MetalLB connectivity issues
# Usage: ./fix-metallb.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl not found. Please ensure k3s is running."
        exit 1
    fi
}

# Function to restart MetalLB
restart_metallb() {
    print_status "Restarting MetalLB speaker pods..."
    kubectl rollout restart daemonset/metallb-speaker -n metallb-system
    sleep 10
    print_success "MetalLB speaker restarted"
}

# Function to restart Traefik
restart_traefik() {
    print_status "Restarting Traefik..."
    kubectl rollout restart deployment/traefik -n kube-system
    sleep 15
    print_success "Traefik restarted"
}

# Function to check connectivity
check_connectivity() {
    print_status "Checking LoadBalancer connectivity..."
    
    local ips=("10.0.2.1" "10.0.2.2" "10.0.2.3" "10.0.2.4")
    local reachable=0
    local total=${#ips[@]}
    
    for ip in "${ips[@]}"; do
        if ping -c 1 -W 5 "$ip" >/dev/null 2>&1; then
            print_success "IP $ip is reachable"
            reachable=$((reachable + 1))
        else
            print_warning "IP $ip is not reachable"
        fi
    done
    
    print_status "Connectivity: $reachable/$total IPs reachable"
    
    if [ "$reachable" -eq "$total" ]; then
        return 0
    else
        return 1
    fi
}

# Function to show current status
show_status() {
    print_status "Current LoadBalancer services:"
    kubectl get services -A --field-selector spec.type=LoadBalancer
    
    echo
    print_status "MetalLB pods:"
    kubectl get pods -n metallb-system
    
    echo
    print_status "Traefik pods:"
    kubectl get pods -n kube-system | grep traefik
}

# Main execution
main() {
    print_status "Starting MetalLB connectivity fix..."
    
    check_kubectl
    
    echo
    print_status "=== Current Status ==="
    show_status
    
    echo
    print_status "=== Checking Connectivity ==="
    if check_connectivity; then
        print_success "All LoadBalancer IPs are reachable!"
        exit 0
    fi
    
    echo
    print_status "=== Applying Fixes ==="
    
    # Restart MetalLB
    restart_metallb
    
    # Wait a bit
    sleep 20
    
    # Restart Traefik if needed
    if ! ping -c 1 -W 5 "10.0.2.1" >/dev/null 2>&1; then
        restart_traefik
        sleep 20
    fi
    
    echo
    print_status "=== Final Check ==="
    if check_connectivity; then
        print_success "Connectivity issues resolved!"
    else
        print_warning "Some connectivity issues may persist. Check network configuration."
    fi
    
    echo
    print_status "=== Final Status ==="
    show_status
}

# Run main function
main "$@"

