# Colin's Kubernetes Cluster Homelab

This repository contains the complete GitOps configuration for a K3s cluster running on Raspberry Pi nodes, managed entirely through ArgoCD.

## 🎯 **Cluster Overview**

- **Master Node**: 192.168.86.27 (pimaster)
- **Worker Node**: 192.168.86.238 (worker-node2)
- **LoadBalancer IP**: 192.168.86.101 (MetalLB)
- **DNS Domain**: cooklabs.net
- **GitOps**: Fully automated with ArgoCD

## **Deployed Applications**

| Application | Namespace | URL | Status |
|-------------|-----------|-----|--------|
| **ArgoCD** | argocd | https://argocd.cooklabs.net | ✅ Running |
| **Mealie** | mealie | https://mealie.cooklabs.net | ✅ Running |
| **Vaultwarden** | vaultwarden | https://vaultwarden.cooklabs.net | ✅ Running |
| **Wazuh** | security | https://wazuh.cooklabs.net | ✅ Running |
| **Grafana** | monitoring | https://grafana.cooklabs.net | ✅ Running |
| **Prometheus** | monitoring | https://prometheus.cooklabs.net | ✅ Running |
| **PostgreSQL** | monitoring | Internal | ✅ Running |


This cluster uses **ArgoCD** for complete GitOps automation:

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
- **Wazuh**: Security information and event management (SIEM)

## 🌐 **Network Configuration**

### **DNS Setup (Cloudflare)**
All applications use the `cooklabs.net` domain with A records pointing to the LoadBalancer IP:

| Domain | IP Address | Purpose |
|--------|------------|---------|
| argocd.cooklabs.net | 192.168.86.101 | ArgoCD GitOps UI |
| mealie.cooklabs.net | 192.168.86.101 | Recipe management |
| vaultwarden.cooklabs.net | 192.168.86.101 | Password manager |
| wazuh.cooklabs.net | 192.168.86.101 | Security monitoring |
| grafana.cooklabs.net | 192.168.86.101 | Monitoring dashboards |
| prometheus.cooklabs.net | 192.168.86.101 | Metrics collection |

### **LoadBalancer Configuration**
- **MetalLB IP Pool**: 192.168.86.100-192.168.86.110
- **Primary LoadBalancer IP**: 192.168.86.101
- **L2 Advertisement**: On wlan0 interface
- **Multi-node**: Master + Worker node support

## 🔐 **Security Features**

### **GitHub Authentication**
- **Secure PAT Management**: GitHub Personal Access Token stored as Kubernetes secret
- **Environment Variables**: No hardcoded credentials in repository
- **Template-based**: Use `argocd/github-repository-secret.yaml.template` and `scripts/deploy-github-secret.sh`

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


### **Emergency Manual Sync**
```bash
# Only use in emergencies when GitOps is broken
kubectl patch application mealie -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```
