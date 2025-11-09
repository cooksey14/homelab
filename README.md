# Colin's Kubernetes Homelab Cluster 

This repository contains the complete GitOps configuration for a K3s cluster running on Raspberry Pi nodes, managed entirely through ArgoCD.

## **Cluster Overview**

- **Master Node**: 10.0.1.10 (k3s-master)
- **Worker Node 1**: 10.0.1.11 (k3s-worker-1)
- **Worker Node 2**: 10.0.1.12 (k3s-worker-2)
- **LoadBalancer IP**: 10.0.2.1 (MetalLB/Traefik)
- **DNS Domain**: cooklabs.net
- **GitOps**: Fully automated with ArgoCD



This cluster uses **ArgoCD** for complete GitOps automation:

### **Application of Applications Pattern**
- **Root Application** (`root-app`) manages all other applications
- **Single point of control** for the entire GitOps workflow
- **Self-managing** - manages itself and all child applications

## **Infrastructure Components**

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
- **Wazuh**: Security information and event management (SIEM)

## **Network Configuration**

### **Network Configuration**
- **Network Range**: 10.0.0.0/16
- **Gateway**: 10.0.0.1
- **DHCP Pool**: 10.0.0.46 - 10.0.255.254
- **Kubernetes Nodes**: 10.0.1.10-10.0.1.12
- **LoadBalancer Pool**: 10.0.2.1-10.0.2.100

### **DNS Setup (Cloudflare)**
All applications use the `cooklabs.net` domain with A records pointing to the LoadBalancer IP:

| Domain | IP Address | Purpose |
|--------|------------|---------|
| argocd.cooklabs.net | 10.0.2.1 | ArgoCD GitOps UI |
| mealie.cooklabs.net | 10.0.2.1 | Recipe management |
| vaultwarden.cooklabs.net | 10.0.2.1 | Password manager |
| wazuh.cooklabs.net | 10.0.2.1 | Security monitoring |
| grafana.cooklabs.net | 10.0.2.1 | Monitoring dashboards |
| prometheus.cooklabs.net | 10.0.2.1 | Metrics collection |

### **LoadBalancer Configuration**
- **MetalLB IP Pool**: 10.0.2.1-10.0.2.100
- **Primary LoadBalancer IP**: 10.0.2.1 (Traefik)
- **Multi-node**: Master + Worker nodes support

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
