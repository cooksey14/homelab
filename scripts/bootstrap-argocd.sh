#!/bin/bash

# Bootstrap ArgoCD to manage itself
echo "Bootstrapping ArgoCD..."

# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD temporarily for bootstrapping
echo "Installing ArgoCD for bootstrapping..."
helm install argocd-bootstrap argo/argo-cd \
  --version 5.51.6 \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=ClusterIP \
  --set server.ingress.enabled=false \
  --set server.insecure=true \
  --set configs.params."server\.insecure"=true \
  --set configs.cm.url=https://argocd.cooklabs.net \
  --set configs.cm."server\.insecure"=true \
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

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s

echo "ArgoCD is ready! Now creating the self-managing Application..."

# Wait a bit more for everything to be ready
sleep 10

# Now create the Application that will manage ArgoCD itself
kubectl apply -f k3s/argocd-applications/argocd.yaml

echo "Waiting for the Application to sync..."
sleep 30

# Check if the Application is syncing
kubectl get application argocd -n argocd

echo "Bootstrap complete! ArgoCD should now be managing itself."
echo "You can now delete the bootstrap installation:"
echo "helm uninstall argocd-bootstrap -n argocd"

