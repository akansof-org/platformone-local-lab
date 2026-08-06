#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_command k3d

print_step "Deleting k3d cluster '${CLUSTER_NAME}'"
if k3d cluster list "${CLUSTER_NAME}" >/dev/null 2>&1; then
  k3d cluster delete "${CLUSTER_NAME}"
else
  echo "k3d cluster '${CLUSTER_NAME}' does not exist."
fi

print_step "Runtime data"
cat <<EOF
Cluster containers and the k3d network have been removed.

Runtime directories are intentionally preserved for inspection:
  ${KUBECONFIG_DIR}
  ${GENERATED_CONFIG_DIR}
  ${REGISTRY_DATA_DIR}

To remove local runtime data too, run:
  CLEAN_RUNTIME=1 ./scripts/cluster/reset.sh
EOF
