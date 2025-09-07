# Wazuh Security Monitoring - Hybrid Approach

## Overview

This setup provides **comprehensive security monitoring** at both the Kubernetes cluster level and the host level.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐  │
│  │   Wazuh Manager │  │ Wazuh Dashboard │  │ Wazuh Agents │  │
│  │   (Container)   │  │   (Container)    │  │ (DaemonSets) │  │
│  └─────────────────┘  └─────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Host Level Monitoring                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐  │
│  │   Pi Master     │  │   Worker Node 1 │  │ Worker Node 2│  │
│  │ Wazuh Agent     │  │ Wazuh Agent     │  │ Wazuh Agent  │  │
│  │ (Host Process)  │  │ (Host Process)  │  │ (Host Process)│  │
│  └─────────────────┘  └─────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## What Each Level Monitors

### Kubernetes Level (Container Agents)
- **Container Runtime**: Docker/containerd events
- **Kubernetes API**: API calls, RBAC violations
- **Pod Security**: Security contexts, policies
- **Network Policies**: Pod-to-pod communication
- **Resource Usage**: CPU, memory, storage
- **Application Logs**: Container application logs

### Host Level (Host Agents)
- **File System**: Changes to host filesystem
- **System Calls**: Kernel-level system calls
- **Hardware Events**: Physical access, hardware changes
- **OS Security**: Login attempts, privilege escalations
- **Network**: Host-level network traffic
- **Boot Security**: Boot process monitoring
- **System Logs**: OS-level logs (/var/log/*)

## Installation Steps

### 1. Deploy Kubernetes Components (Already Done)
```bash
# Your current setup with ARM64 images
kubectl get pods -n security
```

### 2. Install Host-Level Agents

Run this script on each Raspberry Pi:

```bash
# On master node (192.168.86.27)
ssh pi@192.168.86.27
sudo ./install-wazuh-host-agent.sh

# On worker node 1 (192.168.86.31)
ssh pi@192.168.86.31
sudo ./install-wazuh-host-agent.sh

# On worker node 2 (192.168.86.238)
ssh pi@192.168.86.238
sudo ./install-wazuh-host-agent.sh
```

### 3. Verify Installation

Check both levels:

```bash
# Kubernetes level
kubectl get pods -n security -o wide

# Host level
ssh pi@192.168.86.27 "sudo systemctl status wazuh-agent"
ssh pi@192.168.86.31 "sudo systemctl status wazuh-agent"
ssh pi@192.168.86.238 "sudo systemctl status wazuh-agent"
```

## Configuration

### Manager Configuration
The Wazuh manager will receive data from both:
- **Container agents** (via Kubernetes service)
- **Host agents** (via LoadBalancer IP)

### Agent Naming Convention
- **Container agents**: `wazuh-agent-<node-name>-<pod-id>`
- **Host agents**: `<hostname>` (e.g., `pi`, `worker-node-1`)

## Benefits of Hybrid Approach

### Complete Visibility
- **Container attacks**: Malicious containers, privilege escalations
- **Host attacks**: Physical access, OS-level intrusions
- **Network attacks**: Both pod-to-pod and host-level network

### Defense in Depth
- **Multiple detection layers**
- **Redundant monitoring**
- **Comprehensive coverage**

### Compliance
- **Container security standards**
- **Host security standards**
- **Full audit trail**

## Monitoring Dashboard

Access the unified dashboard at:
- **URL**: https://wazuh.cooklabs.net
- **Credentials**: admin/admin (change in production!)

The dashboard will show:
- **All agents** (both container and host)
- **Unified alerts** from all sources
- **Comprehensive security view**

## Troubleshooting

### Container Agents
```bash
kubectl logs -n security -l app.kubernetes.io/component=agent
```

### Host Agents
```bash
ssh pi@192.168.86.27 "sudo tail -f /var/ossec/logs/ossec.log"
```

### Manager Logs
```bash
kubectl logs -n security -l app.kubernetes.io/component=manager
```

## Security Considerations

1. **Change default passwords** in production
2. **Use TLS certificates** for agent-manager communication
3. **Configure firewall rules** for Wazuh ports
4. **Regular updates** of both container and host agents
5. **Monitor agent health** and connectivity

This hybrid approach gives you the **best of both worlds**: Kubernetes-native monitoring AND comprehensive host-level security visibility!
