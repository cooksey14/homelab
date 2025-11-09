#!/bin/bash

# MetalLB Monitoring and Auto-Fix Script
# This script monitors MetalLB LoadBalancer IPs and fixes connectivity issues
# Usage: ./monitor-metallb.sh [--daemon]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
METALLB_IPS=("10.0.2.1" "10.0.2.2" "10.0.2.3" "10.0.2.4")
CHECK_INTERVAL=30
MAX_FAILURES=3
DAEMON_MODE=false

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

# Function to check IP connectivity
check_ip_connectivity() {
    local ip=$1
    local timeout=5
    
    if ping -c 1 -W "$timeout" "$ip" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check HTTP connectivity
check_http_connectivity() {
    local ip=$1
    local port=${2:-80}
    local timeout=10
    
    if curl -s --connect-timeout "$timeout" "http://$ip:$port" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to restart MetalLB speaker
restart_metallb_speaker() {
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

# Function to check MetalLB status
check_metallb_status() {
    print_status "Checking MetalLB status..."
    
    # Check if MetalLB pods are running
    local speaker_pods
    speaker_pods=$(kubectl get pods -n metallb-system -l app=metallb,component=speaker --no-headers | wc -l)
    
    if [ "$speaker_pods" -eq 0 ]; then
        print_error "No MetalLB speaker pods found"
        return 1
    fi
    
    # Check if all speaker pods are ready
    local ready_pods
    ready_pods=$(kubectl get pods -n metallb-system -l app=metallb,component=speaker --no-headers | grep -c "Running" || echo "0")
    
    if [ "$ready_pods" -ne "$speaker_pods" ]; then
        print_warning "Not all MetalLB speaker pods are ready ($ready_pods/$speaker_pods)"
        return 1
    fi
    
    print_success "MetalLB speaker pods are healthy ($ready_pods pods)"
    return 0
}

# Function to check LoadBalancer services
check_loadbalancer_services() {
    print_status "Checking LoadBalancer services..."
    
    local lb_services
    lb_services=$(kubectl get services -A --field-selector spec.type=LoadBalancer --no-headers | wc -l)
    
    if [ "$lb_services" -eq 0 ]; then
        print_warning "No LoadBalancer services found"
        return 1
    fi
    
    print_success "Found $lb_services LoadBalancer services"
    
    # Show LoadBalancer IPs
    kubectl get services -A --field-selector spec.type=LoadBalancer --no-headers | while read -r line; do
        local ip
        ip=$(echo "$line" | awk '{print $5}' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        if [ -n "$ip" ]; then
            echo "  LoadBalancer IP: $ip"
        fi
    done
    
    return 0
}

# Function to perform health check
perform_health_check() {
    local failures=0
    local total_checks=0
    
    print_status "Performing health check on LoadBalancer IPs..."
    
    for ip in "${METALLB_IPS[@]}"; do
        total_checks=$((total_checks + 1))
        
        if check_ip_connectivity "$ip"; then
            print_success "IP $ip is reachable"
        else
            print_error "IP $ip is not reachable"
            failures=$((failures + 1))
        fi
    done
    
    print_status "Health check completed: $((total_checks - failures))/$total_checks IPs reachable"
    
    if [ "$failures" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Function to fix connectivity issues
fix_connectivity_issues() {
    print_status "Attempting to fix connectivity issues..."
    
    # Check MetalLB status first
    if ! check_metallb_status; then
        print_status "MetalLB status check failed, restarting speaker pods..."
        restart_metallb_speaker
        sleep 30
    fi
    
    # Check LoadBalancer services
    if ! check_loadbalancer_services; then
        print_warning "LoadBalancer services check failed"
    fi
    
    # Restart Traefik if Traefik IP is not reachable
    if ! check_ip_connectivity "10.0.2.1"; then
        print_status "Traefik IP not reachable, restarting Traefik..."
        restart_traefik
        sleep 30
    fi
    
    # Perform another health check
    if perform_health_check; then
        print_success "Connectivity issues resolved"
        return 0
    else
        print_warning "Some connectivity issues may persist"
        return 1
    fi
}

# Function to run in daemon mode
run_daemon() {
    print_status "Starting MetalLB monitor in daemon mode (checking every ${CHECK_INTERVAL}s)..."
    print_status "Press Ctrl+C to stop"
    
    local consecutive_failures=0
    
    while true; do
        echo
        print_status "=== MetalLB Health Check $(date) ==="
        
        if perform_health_check; then
            consecutive_failures=0
            print_success "All LoadBalancer IPs are healthy"
        else
            consecutive_failures=$((consecutive_failures + 1))
            print_warning "Health check failed ($consecutive_failures/$MAX_FAILURES)"
            
            if [ "$consecutive_failures" -ge "$MAX_FAILURES" ]; then
                print_error "Multiple consecutive failures detected, attempting to fix..."
                if fix_connectivity_issues; then
                    consecutive_failures=0
                else
                    print_error "Failed to fix connectivity issues"
                fi
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --daemon    Run in daemon mode with continuous monitoring"
    echo "  --check     Perform a single health check"
    echo "  --fix       Attempt to fix connectivity issues"
    echo "  --status    Show MetalLB status"
    echo "  --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --check"
    echo "  $0 --daemon"
    echo "  $0 --fix"
}

# Main execution
main() {
    case "${1:-check}" in
        --daemon)
            DAEMON_MODE=true
            run_daemon
            ;;
        --check)
            perform_health_check
            ;;
        --fix)
            fix_connectivity_issues
            ;;
        --status)
            check_metallb_status
            check_loadbalancer_services
            ;;
        --help)
            show_usage
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
