# Runtime Configuration Patches Applied
# These were applied during troubleshooting and should be documented for reference

## CoreDNS Configuration Fix
# Applied to fix external DNS resolution within the cluster
kubectl patch configmap coredns -n kube-system --type merge -p '{
  "data": {
    "Corefile": ".\\:53 {\\n    errors\\n    health {\\n       lameduck 5s\\n    }\\n    ready\\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\\n       pods insecure\\n       fallthrough in-addr.arpa ip6.arpa\\n       ttl 30\\n    }\\n    prometheus :9153\\n    forward . 8.8.8.8 8.8.4.4 {\\n       max_concurrent 1000\\n    }\\n    cache 30\\n    loop\\n    reload\\n    loadbalance\\n}"
  }
}'

# Restart CoreDNS deployment
kubectl rollout restart deployment coredns -n kube-system

## Traefik NodeSelector Fix
# Applied to ensure Traefik runs on the worker node
kubectl patch deployment traefik -n kube-system --type merge -p '{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "kubernetes.io/hostname": "worker-node-2"
        }
      }
    }
  }
}'

## Manual IP Binding (Temporary Fix)
# These were applied manually on worker-node-2 to fix MetalLB L2 advertisement
sudo ip addr add 192.168.86.107/24 dev wlan0
sudo ip addr add 192.168.86.101/24 dev wlan0

# Note: These manual IP bindings may need to be reapplied after node reboots
# Consider implementing a systemd service or init script for persistence
