#!/bin/bash

# GitHub Repository Setup Script for K3s GitOps
# This script helps you set up your GitHub repository and configure it for GitOps

set -e

echo "🚀 Setting up GitHub repository for K3s GitOps..."

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "❌ Git repository not initialized. Please run 'git init' first."
    exit 1
fi

# Get repository information
read -p "📝 Enter your GitHub username: " GITHUB_USERNAME
read -p "📝 Enter your repository name (e.g., k3s-gitops): " REPO_NAME
read -p "📝 Enter your repository description: " REPO_DESCRIPTION

# Create GitHub repository
echo "🔧 Creating GitHub repository..."
gh repo create "$REPO_NAME" --description "$REPO_DESCRIPTION" --public --source=. --remote=origin --push

# Update ArgoCD applications with GitHub URL
echo "🔄 Updating ArgoCD applications with GitHub URL..."
GITHUB_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME"

# Update all ArgoCD application files
find argocd-applications -name "*.yaml" -exec sed -i "s|https://github.com/your-repo/k3s-config|$GITHUB_URL|g" {} \;

# Commit the changes
git add .
git commit -m "Update ArgoCD applications with GitHub repository URL"

# Push to GitHub
git push origin main

echo "✅ GitHub repository setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Go to your GitHub repository: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo "2. Set up GitHub Secrets in Settings > Secrets and variables > Actions:"
echo "   - K3S_SSH_PRIVATE_KEY: Your SSH private key content"
echo "   - K3S_MASTER_IP: 192.168.86.27"
echo "   - K3S_SSH_USER: pimaster"
echo "3. Apply ArgoCD applications to your cluster:"
echo "   kubectl apply -f argocd-applications/"
echo "4. Your GitOps workflow is now ready!"
echo ""
echo "🔗 Repository URL: $GITHUB_URL"
