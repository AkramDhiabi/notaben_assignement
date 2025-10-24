#!/bin/bash
set -e

echo "Setting up local test environment..."

if ! docker ps >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker."
    exit 1
fi

# Install tools if needed
if ! command -v kind >/dev/null 2>&1; then
    echo "Installing Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-$(uname)-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
fi

# Create Kind cluster
echo "Creating Kind cluster..."
kind get clusters 2>/dev/null | grep -q "notaben-local" && kind delete cluster --name notaben-local
kind create cluster --name notaben-local

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)

# Deploy via ArgoCD
echo "Deploying app via ArgoCD..."
kubectl create namespace nb-challenge
kubectl apply -f argocd/application.yaml
sleep 20
kubectl wait --for=condition=available --timeout=120s deployment/simple-app -n nb-challenge

echo ""
echo "Setup complete!"
echo ""
echo "ArgoCD password: ${ARGOCD_PASSWORD}"
echo ""
echo "Access services with port-forward:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  kubectl port-forward -n nb-challenge svc/simple-app 8081:80"
echo ""
echo "Then visit:"
echo "  ArgoCD: https://localhost:8080 (admin / password above)"
echo "  App: http://localhost:8081"
