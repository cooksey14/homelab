#!/bin/bash

# k3s Cluster Test Script
# This script validates the cluster setup and health
# Usage: ./test-cluster.sh

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

# Function to test command
test_command() {
    local cmd="$1"
    local description="$2"
    
    print_status "Testing: $description"
    if eval "$cmd" >/dev/null 2>&1; then
        print_success "$description - OK"
        return 0
    else
        print_error "$description - FAILED"
        return 1
    fi
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local url="$1"
    local description="$2"
    local expected_status="${3:-200}"
    
    print_status "Testing: $description"
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [ "$status_code" = "$expected_status" ]; then
        print_success "$description - OK (HTTP $status_code)"
        return 0
    else
        print_warning "$description - HTTP $status_code (expected $expected_status)"
        return 1
    fi
}

# Function to check pod readiness
check_pod_readiness() {
    local namespace="$1"
    local app_label="$2"
    
    print_status "Checking pod readiness: $app_label in $namespace"
    local ready_pods
    ready_pods=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$app_label" --no-headers | grep -c "Running" || echo "0")
    
    if [ "$ready_pods" -gt 0 ]; then
        print_success "$app_label pods are running ($ready_pods pods)"
        return 0
    else
        print_error "$app_label pods are not running"
        return 1
    fi
}

# Main test function
main() {
    print_status "Starting k3s cluster validation..."
    echo
    
    local tests_passed=0
    local tests_total=0
    
    # Test 1: k3s installation
    tests_total=$((tests_total + 1))
    if test_command "kubectl version --client" "kubectl client"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 2: Cluster connectivity
    tests_total=$((tests_total + 1))
    if test_command "kubectl get nodes" "Cluster connectivity"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 3: Node status
    tests_total=$((tests_total + 1))
    if test_command "kubectl get nodes | grep -q Ready" "All nodes ready"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 4: Helm installation
    tests_total=$((tests_total + 1))
    if test_command "helm version" "Helm installation"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 5: Namespaces
    tests_total=$((tests_total + 1))
    if test_command "kubectl get namespace argocd monitoring cert-manager metallb-system" "Required namespaces"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 6: ArgoCD pods
    tests_total=$((tests_total + 1))
    if check_pod_readiness "argocd" "argocd-server"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 7: Traefik pods
    tests_total=$((tests_total + 1))
    if check_pod_readiness "kube-system" "traefik"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 8: MetalLB pods
    tests_total=$((tests_total + 1))
    if check_pod_readiness "metallb-system" "metallb"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 9: cert-manager pods
    tests_total=$((tests_total + 1))
    if check_pod_readiness "cert-manager" "cert-manager"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 10: LoadBalancer services
    tests_total=$((tests_total + 1))
    if test_command "kubectl get services -A | grep -q LoadBalancer" "LoadBalancer services"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 11: Ingress resources
    tests_total=$((tests_total + 1))
    if test_command "kubectl get ingress -A | grep -q argocd" "Ingress resources"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 12: Certificates
    tests_total=$((tests_total + 1))
    if test_command "kubectl get certificates -A | grep -q True" "Valid certificates"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 13: ArgoCD HTTP (if accessible)
    tests_total=$((tests_total + 1))
    if test_http_endpoint "http://argocd.cooklabs.net" "ArgoCD HTTP access" "404"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 14: ArgoCD HTTPS (if accessible)
    tests_total=$((tests_total + 1))
    if test_http_endpoint "https://argocd.cooklabs.net" "ArgoCD HTTPS access" "200"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 15: Mealie HTTPS (if accessible)
    tests_total=$((tests_total + 1))
    if test_http_endpoint "https://mealie.cooklabs.net" "Mealie HTTPS access" "200"; then
        tests_passed=$((tests_passed + 1))
    fi
    
    echo
    print_status "Test Results: $tests_passed/$tests_total tests passed"
    
    if [ "$tests_passed" -eq "$tests_total" ]; then
        print_success "All tests passed! Cluster is healthy."
        echo
        print_status "Cluster Summary:"
        kubectl get nodes -o wide
        echo
        print_status "Services:"
        kubectl get services -A | grep LoadBalancer
        echo
        print_status "Ingresses:"
        kubectl get ingress -A
        echo
        print_status "Access URLs:"
        echo "  ArgoCD: https://argocd.cooklabs.net"
        echo "  Grafana: http://192.168.86.27:30180 (admin/admin)"
        echo "  Mealie: https://mealie.cooklabs.net"
        echo "  Pi-hole: https://pihole.cooklabs.net"
        return 0
    else
        print_warning "Some tests failed. Check the output above for details."
        echo
        print_status "Troubleshooting commands:"
        echo "  kubectl get pods -A"
        echo "  kubectl get services -A"
        echo "  kubectl get ingress -A"
        echo "  kubectl logs -n kube-system deployment/traefik"
        return 1
    fi
}

# Run main function
main "$@"

