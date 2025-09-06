# K3s Cluster GitOps Configuration

This repository contains the complete GitOps configuration for your K3s cluster running on Raspberry Pi nodes, managed entirely through ArgoCD.

## 🎯 **Cluster Overview**

- **Master Node**: 192.168.86.27 (pimaster)
- **Worker Node**: 192.168.86.238 (colin)
- **LoadBalancer IP**: 192.168.86.101 (MetalLB)
- **DNS Domain**: cooklabs.net
- **GitOps**: Fully automated with ArgoCD

## 🚀 **Deployed Applications**

| Application | Namespace | URL | Status |
|-------------|-----------|-----|--------|
| **ArgoCD** | argocd | https://argocd.cooklabs.net | ✅ Running |
| **Mealie** | mealie | https://mealie.cooklabs.net | ✅ Running |
| **Vaultwarden** | vaultwarden | https://vaultwarden.cooklabs.net | ✅ Running |
| **Grafana** | monitoring | https://grafana.cooklabs.net | ✅ Running |
| **Prometheus** | monitoring | https://prometheus.cooklabs.net | ✅ Running |
| **PostgreSQL** | monitoring | Internal | ✅ Running |

## 📁 **Repository Structure**

```
k3s/
├── argocd-applications/     # ArgoCD Application definitions
│   ├── mealie.yaml          # Mealie Helm chart application
│   ├── monitoring.yaml      # Monitoring stack application
│   ├── namespaces.yaml      # Namespace definitions
│   ├── vaultwarden.yaml     # Vaultwarden application
│   └── root-app.yaml        # Application of Applications
├── mealie/                  # Mealie Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── monitoring/              # Monitoring Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── vaultwarden/            # Vaultwarden Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── namespaces/              # Namespace definitions
├── metalLB/                 # MetalLB configuration
├── certmanager/             # Cert-Manager configuration
├── argocd/                  # ArgoCD configuration
├── GITOPS_WORKFLOW.md       # GitOps workflow documentation
└── README.md               # This file
```

## 🔄 **GitOps Workflow**

This cluster uses **ArgoCD** for complete GitOps automation:

### **How It Works**
1. **Make changes** in Git (edit YAML files)
2. **Commit and push** to GitHub
3. **ArgoCD automatically detects** changes within 30 seconds
4. **ArgoCD automatically syncs** changes to the cluster
5. **Applications update** automatically with no manual intervention

### **Making Changes**
```bash
# Edit any application configuration
vim argocd-applications/mealie.yaml

# Commit and push
git add argocd-applications/mealie.yaml
git commit -m "Update mealie configuration"
git push

# ArgoCD automatically syncs within 30 seconds
# No manual kubectl commands needed!
```

### **Application of Applications Pattern**
- **Root Application** (`root-app`) manages all other applications
- **Single point of control** for the entire GitOps workflow
- **Self-managing** - manages itself and all child applications

## 🛠️ **Infrastructure Components**

### **Core Infrastructure**
- **K3s**: Lightweight Kubernetes distribution
- **MetalLB**: LoadBalancer service for bare metal
- **Traefik**: Ingress controller for external access
- **Cert-Manager**: Automatic TLS certificate management

### **GitOps & Monitoring**
- **ArgoCD**: GitOps continuous delivery
- **Grafana**: Metrics visualization and dashboards
- **Prometheus**: Metrics collection and alerting
- **PostgreSQL**: Database for monitoring data

### **Applications**
- **Mealie**: Recipe management application
- **Vaultwarden**: Self-hosted password manager

## 🌐 **Network Configuration**

### **DNS Setup (Cloudflare)**
All applications use the `cooklabs.net` domain with A records pointing to the LoadBalancer IP:

| Domain | IP Address | Purpose |
|--------|------------|---------|
| argocd.cooklabs.net | 192.168.86.101 | ArgoCD GitOps UI |
| mealie.cooklabs.net | 192.168.86.101 | Recipe management |
| vaultwarden.cooklabs.net | 192.168.86.101 | Password manager |
| grafana.cooklabs.net | 192.168.86.101 | Monitoring dashboards |
| prometheus.cooklabs.net | 192.168.86.101 | Metrics collection |

### **LoadBalancer Configuration**
- **MetalLB IP Pool**: 192.168.86.100-192.168.86.110
- **Primary LoadBalancer IP**: 192.168.86.101
- **L2 Advertisement**: On wlan0 interface
- **Multi-node**: Master + Worker node support

## 🔐 **Security Features**

### **TLS Certificates**
- **Let's Encrypt**: Automatic TLS certificate generation
- **DNS Challenge**: Uses Cloudflare DNS for validation
- **Auto-renewal**: Certificates automatically renewed

### **Security Contexts**
- **Non-root containers**: All applications run as non-root users
- **Read-only filesystems**: Where appropriate
- **Resource limits**: CPU and memory limits defined
- **Network policies**: Ingress controllers with TLS

## 📊 **Monitoring & Observability**

### **ArgoCD Monitoring**
- **UI**: https://argocd.cooklabs.net
- **Auto-sync**: All applications sync automatically
- **Health checks**: Continuous health monitoring
- **Sync history**: Complete audit trail of changes

### **Application Monitoring**
- **Grafana**: https://grafana.cooklabs.net
- **Prometheus**: https://prometheus.cooklabs.net
- **Metrics**: CPU, memory, network, and custom metrics
- **Alerting**: Configurable alerts and notifications

## 🚀 **Quick Start**

### **1. Access ArgoCD**
```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
open https://argocd.cooklabs.net
```

### **2. Check Application Status**
```bash
# Check all ArgoCD applications
kubectl get applications -n argocd

# Check specific application
kubectl describe application mealie -n argocd
```

### **3. Make Configuration Changes**
```bash
# Edit application configuration
vim argocd-applications/mealie.yaml

# Commit and push (ArgoCD will auto-sync)
git add argocd-applications/mealie.yaml
git commit -m "Update mealie configuration"
git push
```

## 🔧 **Troubleshooting**

### **Check Application Health**
```bash
# Check all pods
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# Check specific application logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### **Common Issues**

1. **Application OutOfSync**
   - Check Git repository access
   - Verify GitHub token is valid
   - Check ArgoCD application logs

2. **DNS Resolution Issues**
   - Verify Cloudflare DNS records
   - Check LoadBalancer IP assignment
   - Test with `nslookup domain.cooklabs.net`

3. **TLS Certificate Issues**
   - Check Cert-Manager logs
   - Verify DNS challenge configuration
   - Check Let's Encrypt rate limits

### **Emergency Manual Sync**
```bash
# Only use in emergencies when GitOps is broken
kubectl patch application mealie -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

## 📚 **Documentation**

- **GitOps Workflow**: See `GITOPS_WORKFLOW.md` for detailed GitOps procedures
- **Application Charts**: Each application has its own Helm chart with documentation
- **ArgoCD UI**: https://argocd.cooklabs.net for visual management

## 🔄 **Updates and Maintenance**

### **Automatic Updates**
- **GitOps**: All changes go through Git commits
- **Auto-sync**: ArgoCD automatically syncs changes
- **Health monitoring**: Continuous health checks
- **Rollback**: Easy rollback through Git history

### **Best Practices**
- ✅ **Make all changes in Git**
- ✅ **Use descriptive commit messages**
- ✅ **Let ArgoCD handle automatic sync**
- ✅ **Monitor application health**
- ❌ **Avoid manual kubectl patches**
- ❌ **Don't bypass Git workflow**

## 🆘 **Support**

If you encounter issues:

1. **Check ArgoCD UI**: https://argocd.cooklabs.net
2. **Review GitOps workflow**: See `GITOPS_WORKFLOW.md`
3. **Check application logs**: Use kubectl commands above
4. **Verify DNS configuration**: Check Cloudflare settings
5. **Test network connectivity**: Verify LoadBalancer IP

## 🎉 **Benefits of This Setup**

- **🔄 Complete GitOps**: All changes tracked in Git
- **⚡ Automatic Sync**: No manual intervention required
- **📊 Full Observability**: Comprehensive monitoring stack
- **🔐 Production Ready**: TLS, security contexts, resource limits
- **🌐 External Access**: All applications accessible via domain names
- **🛡️ High Availability**: Multi-node cluster with LoadBalancer
- **📈 Scalable**: Easy to add more applications and nodes

---

**This cluster is now fully operational with production-ready GitOps workflow!** 🚀