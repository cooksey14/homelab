#!/bin/bash

echo "=== Simple ArgoCD Installation (YAML-based) ==="

# Create namespace
kubectl create namespace argocd

# Install ArgoCD using kubectl apply with a simple configuration
echo "Installing ArgoCD components..."

# Create a simple ArgoCD server deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-server
    spec:
      containers:
      - name: server
        image: quay.io/argoproj/argocd:v3.0.12
        command:
        - argocd-server
        - --insecure
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 3
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: argocd-application-controller
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-application-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-application-controller
    spec:
      containers:
      - name: application-controller
        image: quay.io/argoproj/argocd:v3.0.12
        command:
        - argocd-application-controller
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-repo-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-repo-server
    spec:
      containers:
      - name: repo-server
        image: quay.io/argoproj/argocd:v3.0.12
        command:
        - argocd-repo-server
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8080
    protocol: TCP
  selector:
    app.kubernetes.io/name: argocd-server
EOF

echo "Waiting for ArgoCD to be ready..."
sleep 30

echo "ArgoCD pods:"
kubectl get pods -n argocd

echo ""
echo "ArgoCD LoadBalancer IP:"
kubectl get service argocd-server -n argocd

echo ""
echo "ArgoCD should be accessible at the LoadBalancer IP above"
echo "Default username: admin"
echo "Password will be generated automatically"



