# Colin's Kubernetes Homelab Cluster 

Complete GitOps configuration for K3s cluster on Raspberry Pi nodes, managed through ArgoCD.

## Cluster Overview

- **Master Node**: 10.0.1.10 (k3s-master)
- **Worker Node 1**: 10.0.1.11 (k3s-worker-1)
- **Worker Node 2**: 10.0.1.12 (k3s-worker-2)
- **Ingress**: Nginx with hostNetwork (ports 80/443 on all nodes)
- **DNS Domain**: cooklabs.net
- **GitOps**: Fully automated with ArgoCD
- **Remote Access**: Tailscale for secure remote kubectl/k9s

### Application of Applications Pattern
- Root application manages all child applications
- Single point of control for entire GitOps workflow
- Self-managing infrastructure

## Infrastructure Components

### Core Infrastructure
- **K3s**: Lightweight Kubernetes distribution
- **Nginx Ingress**: Host-network based ingress (no LoadBalancer required)
- **Cert-Manager**: Automatic TLS certificate management
- **Tailscale**: Secure remote access to cluster

### GitOps & Monitoring
- **ArgoCD**: GitOps continuous delivery
- **Grafana**: Metrics visualization and dashboards
- **Prometheus**: Metrics collection and alerting
- **PostgreSQL**: Database for monitoring data

### Applications
- **Mealie**: Recipe management
- **Vaultwarden**: Password manager
- **Wazuh**: Security monitoring (SIEM)
- **Homelab Command Center**: Cluster dashboard

## Network Configuration

### Network Layout
- **Node Subnet**: 10.0.1.0/24 (Nodes at 10.0.1.10-12)
- **Client Subnet**: 10.0.0.0/24 (DHCP: 10.0.0.46-199)
- **Gateway**: 10.0.0.1
- **Ingress**: Direct node access via hostNetwork

### DNS Setup (Cloudflare)
All services use A records pointing to node IPs:

| Domain | IP Address | Purpose |
|--------|------------|---------|
| argocd.cooklabs.net | 10.0.1.10, 10.0.1.11 | ArgoCD GitOps UI |
| homelab.cooklabs.net | 10.0.1.10, 10.0.1.11 | Homelab dashboard |
| mealie.cooklabs.net | 10.0.1.10, 10.0.1.11 | Recipe management |
| vaultwarden.cooklabs.net | 10.0.1.10, 10.0.1.11 | Password manager |
| wazuh.cooklabs.net | 10.0.1.10, 10.0.1.11 | Security monitoring |
| grafana.cooklabs.net | 10.0.1.10, 10.0.1.11 | Monitoring dashboards |
| prometheus.cooklabs.net | 10.0.1.10, 10.0.1.11 | Metrics collection |

Note: Multiple A records provide basic high availability

## Remote Access

### Tailscale Setup
- API server exposed via Tailscale (`k3s-api`)
- Remote kubectl/k9s access from anywhere
- OAuth-based authentication

### Configure Remote Access
See `/remote-access/README.md` for complete setup instructions.

## Monitoring

### ArgoCD
- UI: https://argocd.cooklabs.net
- Auto-sync enabled for all applications
- Continuous health monitoring

### Metrics & Dashboards
- Grafana: https://grafana.cooklabs.net
- Prometheus: https://prometheus.cooklabs.net

## Emergency Procedures

### Force Application Sync
```bash
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```
