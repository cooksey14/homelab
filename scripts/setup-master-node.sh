#!/bin/bash

# k3s Master Node Setup Script
# This script sets up a complete k3s cluster from scratch
# Usage: ./setup-master-node.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MASTER_IP="192.168.86.27"
CLUSTER_CIDR="10.42.0.0/16"
SERVICE_CIDR="10.43.0.0/16"
CLUSTER_DNS="10.43.0.10"
METALLB_POOL="192.168.86.100-192.168.86.110"
DOMAIN="cooklabs.net"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    print_status "Waiting for pods in namespace '$namespace' to be ready..."
    
    kubectl wait --for=condition=ready pod --all -n "$namespace" --timeout="${timeout}s" || {
        print_warning "Some pods in namespace '$namespace' may not be ready yet"
        kubectl get pods -n "$namespace"
    }
}

# Function to install k3s
install_k3s() {
    print_status "Checking if k3s is already installed..."
    
    if command_exists k3s; then
        print_warning "k3s is already installed. Checking status..."
        if systemctl is-active --quiet k3s; then
            print_success "k3s is already running"
            return 0
        else
            print_status "k3s is installed but not running. Starting service..."
            sudo systemctl start k3s
            sudo systemctl enable k3s
        fi
    else
        print_status "Installing k3s..."
        curl -sfL https://get.k3s.io | sh -s - \
            --cluster-cidr="$CLUSTER_CIDR" \
            --service-cidr="$SERVICE_CIDR" \
            --cluster-dns="$CLUSTER_DNS" \
            --disable traefik \
            --disable servicelb \
            --write-kubeconfig-mode 644
        
        print_success "k3s installed successfully"
    fi
    
    # Wait for k3s to be ready
    print_status "Waiting for k3s to be ready..."
    sleep 30
    
    # Verify installation
    if kubectl get nodes >/dev/null 2>&1; then
        print_success "k3s cluster is ready"
        kubectl get nodes
    else
        print_error "k3s cluster is not ready"
        exit 1
    fi
}

# Function to install Helm
install_helm() {
    print_status "Checking if Helm is installed..."
    
    if command_exists helm; then
        print_success "Helm is already installed: $(helm version --short)"
        return 0
    fi
    
    print_status "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    print_success "Helm installed successfully: $(helm version --short)"
}

# Function to add Helm repositories
add_helm_repos() {
    print_status "Adding Helm repositories..."
    
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add traefik https://traefik.github.io/charts
    helm repo add metallb https://metallb.github.io/metallb
    helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes
    helm repo add jetstack https://charts.jetstack.io
    
    helm repo update
    
    print_success "Helm repositories added and updated"
}

# Function to create namespaces
create_namespaces() {
    print_status "Creating namespaces..."
    
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace mealie --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace pihole --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Namespaces created"
}

# Function to install cert-manager
install_cert_manager() {
    print_status "Installing cert-manager..."
    
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --wait
    
    wait_for_pods "cert-manager"
    
    # Create ClusterIssuer
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: cook.colin13@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod-dns
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
    
    print_success "cert-manager installed and configured"
}

# Function to install Traefik
install_traefik() {
    print_status "Installing Traefik..."
    
    helm upgrade --install traefik traefik/traefik \
        --namespace kube-system \
        --set service.type=LoadBalancer \
        --set ports.web.redirectTo=websecure \
        --set ports.websecure.tls.enabled=true \
        --wait
    
    wait_for_pods "kube-system" 600
    
    print_success "Traefik installed"
}

# Function to install MetalLB
install_metallb() {
    print_status "Installing MetalLB..."
    
    helm upgrade --install metallb metallb/metallb \
        --namespace metallb-system \
        --create-namespace \
        --wait
    
    wait_for_pods "metallb-system"
    
    # Configure MetalLB
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_POOL
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
  interfaces:
  - wlan0
EOF
    
    print_success "MetalLB installed and configured"
}

# Function to install PostgreSQL
install_postgresql() {
    print_status "Installing PostgreSQL..."
    
    helm upgrade --install postgres bitnami/postgresql \
        --namespace monitoring \
        --set auth.postgresPassword=postgres \
        --set auth.database=grafana \
        --set auth.username=grafana \
        --set auth.password=YGE0Sle03 \
        --wait
    
    wait_for_pods "monitoring"
    
    print_success "PostgreSQL installed"
}

# Function to install Prometheus
install_prometheus() {
    print_status "Installing Prometheus..."
    
    # Create Prometheus PVC
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-usb-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
EOF
    
    # Install Prometheus
    helm upgrade --install prometheus prometheus-community/prometheus \
        --namespace monitoring \
        --set server.persistentVolume.enabled=true \
        --set server.persistentVolume.existingClaim=prometheus-usb-pvc \
        --set server.nodeSelector."kubernetes\.io/hostname"=pi \
        --wait
    
    wait_for_pods "monitoring"
    
    print_success "Prometheus installed"
}

# Function to install Grafana
install_grafana() {
    print_status "Installing Grafana..."
    
    # Create Grafana DB secret
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: grafana-db-secret
  namespace: monitoring
type: Opaque
data:
  password: WUdFbjBTbGUwMw==
EOF
    
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --set admin.user=admin \
        --set admin.password=admin \
        --set service.type=NodePort \
        --set service.nodePort=30180 \
        --set database.type=postgresql \
        --set database.host=postgres-postgresql.monitoring.svc.cluster.local \
        --set database.port=5432 \
        --set database.user=grafana \
        --set database.name=grafana \
        --set database.password.secretName=grafana-db-secret \
        --set database.password.key=password \
        --wait
    
    wait_for_pods "monitoring"
    
    print_success "Grafana installed"
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    cat <<EOF | kubectl apply -f -
server:
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - argocd.$DOMAIN
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
      traefik.ingress.kubernetes.io/router.tls: "true"
      cert-manager.io/cluster-issuer: letsencrypt-prod-dns
    tls:
      - hosts:
          - argocd.$DOMAIN
        secretName: argocd-tls
  extraArgs:
    - --basehref=/
    - --insecure
EOF
    
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --values /dev/stdin \
        --wait
    
    wait_for_pods "argocd"
    
    print_success "ArgoCD installed"
}

# Function to install Pi-hole
install_pihole() {
    print_status "Installing Pi-hole..."
    
    helm upgrade --install pihole mojo2600/pihole \
        --namespace pihole \
        --create-namespace \
        --set service.dns.type=LoadBalancer \
        --set service.web.type=LoadBalancer \
        --set ingress.enabled=true \
        --set ingress.className=traefik \
        --set ingress.hosts[0].host=pihole.$DOMAIN \
        --set ingress.tls[0].secretName=pihole-tls \
        --set ingress.tls[0].hosts[0]=pihole.$DOMAIN \
        --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod-dns \
        --wait
    
    wait_for_pods "pihole"
    
    print_success "Pi-hole installed"
}

# Function to install Mealie
install_mealie() {
    print_status "Installing Mealie..."
    
    # Create Mealie namespace and deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mealie
  namespace: mealie
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mealie
  template:
    metadata:
      labels:
        app: mealie
    spec:
      containers:
      - name: mealie
        image: ghcr.io/mealie-recipes/mealie:v1.4.0
        ports:
        - containerPort: 9000
        env:
        - name: ALLOW_SIGNUP
          value: "true"
        - name: DB_TYPE
          value: "sqlite"
        - name: TZ
          value: "America/Chicago"
        volumeMounts:
        - name: mealie-data
          mountPath: /app/data
      volumes:
      - name: mealie-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: mealie
  namespace: mealie
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 9000
  selector:
    app: mealie
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mealie
  namespace: mealie
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod-dns
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  rules:
  - host: mealie.$DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mealie
            port:
              number: 80
  tls:
  - hosts:
    - mealie.$DOMAIN
    secretName: mealie-tls
EOF
    
    wait_for_pods "mealie"
    
    print_success "Mealie installed"
}

# Function to display cluster information
display_cluster_info() {
    print_success "Cluster setup completed successfully!"
    echo
    print_status "Cluster Information:"
    echo "  Master IP: $MASTER_IP"
    echo "  Cluster CIDR: $CLUSTER_CIDR"
    echo "  Service CIDR: $SERVICE_CIDR"
    echo "  MetalLB Pool: $METALLB_POOL"
    echo
    print_status "Services:"
    kubectl get services -A | grep LoadBalancer
    echo
    print_status "Ingresses:"
    kubectl get ingress -A
    echo
    print_status "ArgoCD Admin Password:"
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    echo
    echo
    print_status "Access URLs:"
    echo "  ArgoCD: https://argocd.$DOMAIN"
    echo "  Grafana: http://$MASTER_IP:30180 (admin/admin)"
    echo "  Mealie: https://mealie.$DOMAIN"
    echo "  Pi-hole: https://pihole.$DOMAIN"
}

# Main execution
main() {
    print_status "Starting k3s master node setup..."
    
    install_k3s
    install_helm
    add_helm_repos
    create_namespaces
    install_cert_manager
    install_traefik
    install_metallb
    install_postgresql
    install_prometheus
    install_grafana
    install_argocd
    install_pihole
    install_mealie
    
    display_cluster_info
    
    print_success "Master node setup completed successfully!"
}

# Run main function
main "$@"
