#!/bin/bash
#######################################################
# Bootstrap script for setting up the homelab cluster #
#######################################################

# Grab script directory and repo root to use for relative paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Pull talosconfig and kubeconfig]
echo "Pulling configs..."
tofu -chdir="$REPO_ROOT/opentofu" output -raw talosconfig > ~/.talos/config
tofu -chdir="$REPO_ROOT/opentofu" output -raw kubeconfig > ~/.kube/config

# Wait for the Kubernetes API to be ready
until kubectl get --raw=/readyz >/dev/null 2>&1; do
  echo "Waiting for Kubernetes API to be ready..."
  sleep 5
done

#########################################################################################################
# Setup cilium                                                                                          #
# https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium#without-kube-proxy-%2B-gateway-api #
# https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#installation            #
#########################################################################################################
echo "Installing Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

echo "Installing Cilium..."
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install  \
    cilium \
    cilium/cilium \
    --version 1.18.0 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=true \
    --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set cgroup.autoMount.enabled=false \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set k8sServiceHost=localhost \
    --set k8sServicePort=7445 \
    --set gatewayAPI.enabled=true \
    --set gatewayAPI.enableAlpn=true \
    --set gatewayAPI.enableAppProtocol=true \
    --set l2announcements.enabled=true # Not from linked doc


###########################################################################################################################
# Setup ArgoCD                                                                                                            #
# https://docs.siderolabs.com/kubernetes-guides/advanced-guides/deploy-argocd#installation-on-self-managed-talos-clusters #
###########################################################################################################################
echo "Installing ArgoCD..."
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready..."
kubectl -n argocd wait --for=condition=available --timeout=300s deployment/argocd-server

echo "Applying root Application..."
kubectl apply -f "$REPO_ROOT/gitops/root-app.yaml"