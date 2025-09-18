#!/bin/bash

echo "=== Simple ArgoCD Installation ==="

# Create namespace
kubectl create namespace argocd

# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD with simple configuration
echo "Installing ArgoCD..."
helm install argocd argo/argo-cd \
  --version 5.51.6 \
  --namespace argocd \
  --set server.service.type=LoadBalancer \
  --set server.ingress.enabled=false \
  --set server.insecure=true \
  --set configs.params."server\.insecure"=true \
  --set configs.cm.url=https://argocd.cooklabs.net \
  --set configs.cm."server\.insecure"=true \
  --set controller.enabled=true \
  --set repoServer.enabled=true \
  --set redis.enabled=true \
  --set dex.enabled=true \
  --set notifications.enabled=true \
  --set applicationSet.enabled=true

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s

echo "ArgoCD is ready!"
kubectl get pods -n argocd

echo ""
echo "ArgoCD LoadBalancer IP:"
kubectl get service argocd-server -n argocd

echo ""
echo "Now you can access ArgoCD at the LoadBalancer IP above"
echo "Default username: admin"
echo "Get password with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

