#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

"${SCRIPT_DIR}/destroy.sh"

if [[ "${CLEAN_RUNTIME:-0}" == "1" ]]; then
  print_step "Removing PlatformOne local runtime data"
  rm -rf "${KUBECONFIG_DIR}/k3d-${CLUSTER_NAME}.yaml" "${GENERATED_CONFIG_DIR:?}/"* "${REGISTRY_DATA_DIR:?}/"*
else
  print_step "Recreating cluster with preserved runtime data"
fi

"${SCRIPT_DIR}/create.sh"
"${SCRIPT_DIR}/validate.sh"
