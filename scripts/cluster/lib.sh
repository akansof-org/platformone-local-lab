#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-dev}"
K3D_CONFIG="${K3D_CONFIG:-${LAB_DIR}/k3d/cluster-dev.k3d.yaml}"
KUBECONFIG_DIR="${KUBECONFIG_DIR:-${REPO_ROOT}/09-runtime/kubeconfigs}"
GENERATED_CONFIG_DIR="${GENERATED_CONFIG_DIR:-${REPO_ROOT}/09-runtime/generated-config}"
REGISTRY_DATA_DIR="${REGISTRY_DATA_DIR:-${REPO_ROOT}/09-runtime/local-registry/k3d-dev}"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    return 1
  fi
}

print_step() {
  printf '\n==> %s\n' "$1"
}

wait_for_kube_system_deployment() {
  local deployment_name="$1"

  if kubectl get deployment "${deployment_name}" -n kube-system >/dev/null 2>&1; then
    kubectl wait \
      --for=condition=Available \
      "deployment/${deployment_name}" \
      -n kube-system \
      --timeout=180s
  else
    echo "Skipping kube-system deployment '${deployment_name}' because it is not installed."
  fi
}
