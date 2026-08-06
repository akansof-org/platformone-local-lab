#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

"${SCRIPT_DIR}/prereqs.sh"

print_step "Preparing local runtime directories"
mkdir -p "${KUBECONFIG_DIR}" "${GENERATED_CONFIG_DIR}" "${REGISTRY_DATA_DIR}"

if k3d cluster list "${CLUSTER_NAME}" >/dev/null 2>&1; then
  print_step "Cluster already exists"
  echo "k3d cluster '${CLUSTER_NAME}' already exists. Run 'make cluster-verify' to validate it."
  exit 0
fi

print_step "Creating k3d cluster '${CLUSTER_NAME}'"
k3d cluster create --config "${K3D_CONFIG}"

print_step "Writing dedicated kubeconfig"
k3d kubeconfig get "${CLUSTER_NAME}" > "${KUBECONFIG_DIR}/k3d-${CLUSTER_NAME}.yaml"

print_step "Creating baseline namespaces"
kubectl create namespace platformone --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace platformone-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -

print_step "Waiting for core workloads"
kubectl wait --for=condition=Ready nodes --all --timeout=180s
wait_for_kube_system_deployment coredns
wait_for_kube_system_deployment local-path-provisioner
wait_for_kube_system_deployment metrics-server
wait_for_kube_system_deployment traefik

print_step "Cluster is ready"
kubectl get nodes -o wide
