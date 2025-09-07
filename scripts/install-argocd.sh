#!/bin/bash

# Install ArgoCD using Helm
echo "Installing ArgoCD..."

# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD with our configuration
helm install argocd argo/argo-cd \
  --version 5.51.6 \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=ClusterIP \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=traefik \
  --set server.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod-dns \
  --set server.ingress.annotations."traefik\.ingress\.kubernetes\.io/router\.entrypoints"=web,websecure \
  --set server.ingress.annotations."traefik\.ingress\.kubernetes\.io/router\.tls"=true \
  --set server.ingress.hosts[0]=argocd.cooklabs.net \
  --set server.ingress.tls[0].secretName=argocd-server-tls \
  --set server.ingress.tls[0].hosts[0]=argocd.cooklabs.net \
  --set server.insecure=true \
  --set configs.params."server\.insecure"=true \
  --set configs.cm.url=https://argocd.cooklabs.net \
  --set configs.cm."server\.insecure"=true \
  --set configs.repositories.homelab.type=git \
  --set configs.repositories.homelab.url=https://github.com/cooksey14/homelab.git \
  --set configs.repositories.homelab.name=homelab \
  --set controller.enabled=true \
  --set controller.replicas=1 \
  --set repoServer.enabled=true \
  --set repoServer.replicas=1 \
  --set redis.enabled=true \
  --set redis.persistence.enabled=true \
  --set redis.persistence.size=1Gi \
  --set redis.persistence.storageClass=local-path \
  --set dex.enabled=true \
  --set notifications.enabled=true \
  --set applicationSet.enabled=true

echo "ArgoCD installation completed!"
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s

echo "ArgoCD is ready!"
kubectl get pods -n argocd
