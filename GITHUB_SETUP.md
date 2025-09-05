# GitHub GitOps Setup Guide

This guide will help you set up a complete GitHub-based GitOps workflow for your K3s cluster.

## 🚀 Quick Start

### 1. Prerequisites

- GitHub CLI (`gh`) installed
- SSH key pair for cluster access
- kubectl configured for your K3s cluster

### 2. Repository Setup

```bash
# Make the setup script executable
chmod +x setup-github.sh

# Run the setup script
./setup-github.sh
```

### 3. GitHub Secrets Configuration

Go to your repository → Settings → Secrets and variables → Actions, and add:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `K3S_SSH_PRIVATE_KEY` | Your SSH private key content | For cluster access |
| `K3S_MASTER_IP` | `192.168.86.27` | Master node IP |
| `K3S_SSH_USER` | `pimaster` | SSH username |

### 4. Apply ArgoCD Applications

```bash
# Apply ArgoCD applications to enable GitOps
kubectl apply -f argocd-applications/
```

## 🔄 GitHub Actions Workflows

### 1. Manifest Validation (`validate-manifests.yml`)
- **Triggers**: Push to main/develop, PRs
- **Purpose**: Validates YAML syntax and Kubernetes manifests
- **Features**:
  - YAML syntax validation
  - Kubernetes manifest validation
  - Common configuration checks
  - Secret detection warnings

### 2. Deployment (`deploy-to-k3s.yml`)
- **Triggers**: Push to main, manual dispatch
- **Purpose**: Deploys configurations to K3s cluster
- **Features**:
  - Automated deployment
  - Environment selection (production/staging)
  - Deployment verification
  - Status reporting

### 3. ArgoCD Sync (`argocd-sync.yml`)
- **Triggers**: Push to main, hourly schedule, manual dispatch
- **Purpose**: Syncs ArgoCD applications
- **Features**:
  - Automated ArgoCD sync
  - Application status monitoring
  - Hourly sync to ensure consistency

### 4. Security Scan (`security-scan.yml`)
- **Triggers**: Push to main, PRs, daily schedule
- **Purpose**: Security scanning and validation
- **Features**:
  - Trivy vulnerability scanning
  - Secret detection
  - RBAC validation
  - SARIF report upload

## 📁 Repository Structure

```
k3s/
├── .github/
│   └── workflows/
│       ├── validate-manifests.yml
│       ├── deploy-to-k3s.yml
│       ├── argocd-sync.yml
│       └── security-scan.yml
├── namespaces/
├── applications/
├── argocd-applications/
├── secrets/
├── ingress-controllers/
├── setup-github.sh
├── deploy.sh
└── README.md
```

## 🔧 Manual Deployment

If you prefer manual deployment over GitOps:

```bash
# Apply all configurations
./deploy.sh

# Or apply individually
kubectl apply -f namespaces/
kubectl apply -f secrets/
kubectl apply -f applications/monitoring/prometheus/
kubectl apply -f applications/mealie/
kubectl apply -f certmanager/
kubectl apply -f metalLB/metallb-config.yaml
```

## 🔍 Monitoring and Troubleshooting

### Check Workflow Status
- Go to your GitHub repository → Actions tab
- Monitor workflow runs and logs

### Check Cluster Status
```bash
# Check all pods
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# Check specific application
argocd app get <app-name>
```

### Common Issues

1. **SSH Connection Failed**
   - Verify SSH key is correct
   - Check master node IP and username
   - Ensure SSH key has proper permissions

2. **ArgoCD Sync Failed**
   - Check repository URL in ArgoCD applications
   - Verify GitHub repository is accessible
   - Check ArgoCD server connectivity

3. **Deployment Failed**
   - Check YAML syntax
   - Verify namespace exists
   - Check resource quotas and limits

## 🔐 Security Best Practices

1. **Secrets Management**
   - Never commit secrets to Git
   - Use Kubernetes secrets or external secret management
   - Rotate secrets regularly

2. **RBAC**
   - Use least privilege principle
   - Review and audit RBAC configurations
   - Use service accounts for applications

3. **Network Policies**
   - Implement network segmentation
   - Use ingress controllers with TLS
   - Monitor network traffic

## 📊 Monitoring URLs

- **ArgoCD**: https://argocd.cooklabs.net
- **Grafana**: http://192.168.86.27:30180 (admin/admin)
- **Prometheus**: http://192.168.86.27:30089
- **Mealie**: https://mealie.cooklabs.net

## 🆘 Support

If you encounter issues:

1. Check GitHub Actions logs
2. Review ArgoCD application status
3. Check cluster pod logs
4. Verify network connectivity
5. Review security scan results

## 🔄 Updates and Maintenance

- **Regular Updates**: GitHub Actions will automatically sync changes
- **Security Patches**: Security scan runs daily
- **Backup**: Consider backing up your Git repository
- **Monitoring**: Monitor ArgoCD application health
