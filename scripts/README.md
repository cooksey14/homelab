# k3s Cluster Automation Scripts

This directory contains automation scripts for setting up and managing a k3s cluster on Raspberry Pi nodes.

## Scripts Overview

### 1. `setup-master-node.sh`
Complete setup script for the master node. Installs k3s, Helm, and all required applications.

### 2. `join-worker-node.sh`
Script to join worker nodes to an existing k3s cluster.

### 3. `get-k3s-token.sh`
Helper script to retrieve the k3s token from the master node.

## Prerequisites

### Master Node Requirements
- Raspberry Pi running Debian/Ubuntu
- Internet connectivity
- Root or sudo access
- At least 4GB RAM recommended
- SD card with at least 32GB storage

### Worker Node Requirements
- Raspberry Pi running Debian/Ubuntu
- Internet connectivity
- Root or sudo access
- Network connectivity to master node
- Unique hostname

## Quick Start

### 1. Setup Master Node

```bash
# Make script executable
chmod +x setup-master-node.sh

# Run setup (this will take 10-15 minutes)
./setup-master-node.sh
```

The script will:
- Install k3s with custom configuration
- Install Helm and add required repositories
- Create namespaces
- Install cert-manager with Let's Encrypt
- Install Traefik as ingress controller
- Install MetalLB for LoadBalancer services
- Install PostgreSQL, Prometheus, and Grafana
- Install ArgoCD for GitOps
- Install Pi-hole for DNS
- Install Mealie application

### 2. Join Worker Nodes

```bash
# Make script executable
chmod +x join-worker-node.sh

# Join worker node (replace with your master IP)
./join-worker-node.sh 192.168.86.27
```

The script will:
- Install k3s agent
- Configure networking
- Join the cluster
- Label the node for workloads

### 3. Get k3s Token (if needed)

```bash
# Make script executable
chmod +x get-k3s-token.sh

# Get token from master
./get-k3s-token.sh 192.168.86.27
```

## Configuration

### Network Configuration
- **Master IP**: 192.168.86.27 (configurable)
- **Cluster CIDR**: 10.42.0.0/16
- **Service CIDR**: 10.43.0.0/16
- **MetalLB Pool**: 192.168.86.100-192.168.86.110
- **Domain**: cooklabs.net

### Applications Installed
- **ArgoCD**: https://argocd.cooklabs.net
- **Grafana**: http://192.168.86.27:30180 (admin/admin)
- **Mealie**: https://mealie.cooklabs.net
- **Pi-hole**: https://pihole.cooklabs.net
- **Prometheus**: Internal cluster access

## Post-Installation

### 1. Access ArgoCD
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access web UI
open https://argocd.cooklabs.net
```

### 2. Configure DNS
Update your DNS records to point to the LoadBalancer IPs:
- `argocd.cooklabs.net` → 192.168.86.102 (Traefik)
- `mealie.cooklabs.net` → 192.168.86.102 (Traefik)
- `pihole.cooklabs.net` → 192.168.86.102 (Traefik)

### 3. Deploy Applications via ArgoCD
The scripts set up ArgoCD for GitOps. You can deploy applications by:
1. Creating ArgoCD Applications
2. Using the GitOps workflow
3. Syncing from your Git repository

## Troubleshooting

### Common Issues

#### 1. MetalLB LoadBalancer Connectivity Issues
**Symptoms**: Intermittent connectivity to services (ArgoCD, Mealie, etc.)
**Cause**: MetalLB Layer 2 advertisement issues, WiFi reconnections, or pod restarts

**Quick Fix**:
```bash
# Run the fix script
./fix-metallb.sh

# Or manually restart MetalLB
kubectl rollout restart daemonset/metallb-speaker -n metallb-system
kubectl rollout restart deployment/traefik -n kube-system
```

**Monitoring**:
```bash
# Check connectivity
./monitor-metallb.sh --check

# Run continuous monitoring
./monitor-metallb.sh --daemon
```

**Prevention**: Set up the MetalLB monitor as a systemd service:
```bash
sudo cp metallb-monitor.service /etc/systemd/system/
sudo systemctl enable metallb-monitor
sudo systemctl start metallb-monitor
```

#### 2. k3s Installation Fails
```bash
# Check system requirements
free -h
df -h

# Check network connectivity
ping 8.8.8.8

# Check for conflicting services
sudo systemctl status docker
sudo systemctl status containerd
```

#### 2. Worker Node Cannot Join
```bash
# Check network connectivity to master
ping 192.168.86.27
telnet 192.168.86.27 6443

# Verify token
./get-k3s-token.sh 192.168.86.27

# Check k3s agent logs
sudo journalctl -u k3s -f
```

#### 3. Applications Not Accessible
```bash
# Check ingress status
kubectl get ingress -A

# Check services
kubectl get services -A

# Check pods
kubectl get pods -A

# Check Traefik logs
kubectl logs -n kube-system deployment/traefik
```

#### 4. Certificate Issues
```bash
# Check cert-manager
kubectl get certificates -A
kubectl describe certificate <cert-name>

# Check ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod-dns
```

### Useful Commands

```bash
# Check cluster status
kubectl get nodes -o wide
kubectl get pods -A

# Check services
kubectl get services -A | grep LoadBalancer

# Check ingress
kubectl get ingress -A

# Restart services
sudo systemctl restart k3s
kubectl rollout restart deployment/traefik -n kube-system

# View logs
sudo journalctl -u k3s -f
kubectl logs -n kube-system deployment/traefik -f
```

## Customization

### Modify Configuration
Edit the variables at the top of each script:
- `MASTER_IP`: Master node IP address
- `CLUSTER_CIDR`: Pod network CIDR
- `SERVICE_CIDR`: Service network CIDR
- `METALLB_POOL`: LoadBalancer IP pool
- `DOMAIN`: Your domain name

### Add Custom Applications
1. Modify `setup-master-node.sh` to include your applications
2. Create Helm values files
3. Add installation functions
4. Update the main execution flow

### Modify Node Labels
Edit the `configure_workloads()` function in `join-worker-node.sh` to add custom node labels for workload scheduling.

## Security Considerations

1. **Change Default Passwords**: Update default passwords for Grafana, PostgreSQL, etc.
2. **Secure SSH**: Use SSH keys instead of passwords
3. **Firewall**: Configure appropriate firewall rules
4. **Updates**: Regularly update the system and applications
5. **Backups**: Implement regular backups of cluster state and data

## Backup and Recovery

### Backup Cluster State
```bash
# Backup k3s data
sudo tar -czf k3s-backup-$(date +%Y%m%d).tar.gz /var/lib/rancher/k3s/

# Backup application data
kubectl get all -A -o yaml > cluster-state-$(date +%Y%m%d).yaml
```

### Recovery
1. Restore k3s data: `sudo tar -xzf k3s-backup-*.tar.gz -C /`
2. Restart k3s: `sudo systemctl restart k3s`
3. Restore applications via ArgoCD or Helm

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review application logs
3. Check GitHub issues
4. Consult k3s documentation

## License

These scripts are provided as-is for educational and personal use.
