#!/bin/bash

# Secure ArgoCD Repository Secret Deployment Script
# This script creates the GitHub repository secret for ArgoCD using environment variables

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if GITHUB_PAT environment variable is set
if [ -z "$GITHUB_PAT" ]; then
    print_error "GITHUB_PAT environment variable is not set!"
    echo ""
    echo "Please set your GitHub Personal Access Token:"
    echo "  export GITHUB_PAT=your_github_token_here"
    echo ""
    echo "Or run this script with the token:"
    echo "  GITHUB_PAT=your_token ./deploy-github-secret.sh"
    echo ""
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

print_status "Creating ArgoCD GitHub repository secret..."

# Create the secret using kubectl with environment variable substitution
kubectl create secret generic github-repo-secret \
    --namespace=argocd \
    --from-literal=type=git \
    --from-literal=url=https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}.git \
    --from-literal=username=${GITHUB_USERNAME} \
    --from-literal=password="$GITHUB_PAT" \
    --dry-run=client -o yaml | \
kubectl label -f - argocd.argoproj.io/secret-type=repository --local -o yaml | \
kubectl apply -f -

print_success "GitHub repository secret created successfully!"

print_status "Verifying secret creation..."
kubectl get secret github-repo-secret -n argocd

print_success "ArgoCD can now authenticate with GitHub using the secure secret!"
echo ""
print_warning "Remember to:"
echo "  - Never commit your GITHUB_PAT to Git"
echo "  - Add GITHUB_PAT to your .bashrc/.zshrc for persistence"
echo "  - Use GitHub Actions secrets for CI/CD pipelines"
