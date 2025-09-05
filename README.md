# K3s Cluster Configuration

This repository contains the complete GitOps configuration for your K3s cluster running on Raspberry Pi nodes.

## Cluster Overview

- **Master Node**: 192.168.86.27 (pimaster)
- **Applications**: ArgoCD, Grafana, Prometheus, PostgreSQL, Mealie, Cert-Manager, MetalLB
- **Ingress Controllers**: Traefik (192.168.86.102), Nginx (192.168.86.101)

## Directory Structure

```
k3s/
├── namespaces/           # Namespace definitions
├── applications/         # Application configurations
│   ├── monitoring/       # Grafana, Prometheus, PostgreSQL
│   └── mealie/          # Mealie recipe app
├── argocd/              # ArgoCD configuration
├── argocd-applications/ # ArgoCD Application definitions
├── certmanager/         # Cert-Manager configuration
├── metalLB/             # MetalLB configuration
├── ingress-controllers/ # Traefik and Nginx configurations
└── secrets/              # Secret definitions
```

## Current Applications

### ArgoCD
- **Namespace**: argocd
- **URL**: https://argocd.cooklabs.net
- **Status**: Running (7 pods)

### Monitoring Stack
- **Namespace**: monitoring
- **Components**:
  - Grafana: NodePort 30180
  - Prometheus: NodePort 30089 (needs fixing)
  - PostgreSQL: ClusterIP service

### Mealie
- **Namespace**: mealie
- **URL**: https://mealie.cooklabs.net
- **LoadBalancer IP**: 192.168.86.108

### Cert-Manager
- **Namespace**: cert-manager
- **Issuers**: Let's Encrypt (HTTP and DNS challenges)

### MetalLB
- **Namespace**: metallb-system
- **IP Pool**: 192.168.86.100-192.168.86.110

## Issues Found and Fixed

1. **Missing grafana-db-secret**: Created with PostgreSQL password
2. **Prometheus misconfiguration**: Was running nginx instead of Prometheus
3. **Missing namespace definitions**: Created for all namespaces
4. **Missing Helm values**: Exported current configurations

## Next Steps

1. **Apply the grafana-db-secret**:
   ```bash
   kubectl apply -f k3s/secrets/grafana-db-secret.yaml
   ```

2. **Fix Prometheus deployment**:
   ```bash
   kubectl delete deployment prometheus -n monitoring
   kubectl apply -f k3s/applications/monitoring/prometheus/
   ```

3. **Set up GitOps with ArgoCD**:
   - Push this repository to GitHub
   - Update ArgoCD Application URLs
   - Apply ArgoCD Applications

4. **Create GitHub repository**:
   - Initialize git repository
   - Push to GitHub
   - Update ArgoCD Application repoURLs

## Deployment Commands

```bash
# Apply namespaces
kubectl apply -f k3s/namespaces/

# Apply secrets
kubectl apply -f k3s/secrets/

# Apply applications
kubectl apply -f k3s/applications/monitoring/prometheus/
kubectl apply -f k3s/applications/mealie/

# Apply ArgoCD applications (after setting up Git repo)
kubectl apply -f k3s/argocd-applications/
```

## SSH Access

```bash
ssh -i /Users/colin/pi/pi pimaster@192.168.86.27
```

## Monitoring URLs

- Grafana: http://192.168.86.27:30180 (admin/admin)
- Prometheus: http://192.168.86.27:30089
- ArgoCD: https://argocd.cooklabs.net
- Mealie: https://mealie.cooklabs.net
