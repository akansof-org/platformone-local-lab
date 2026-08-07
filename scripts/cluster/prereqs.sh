#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

print_step "Checking required local cluster tools"

missing=0
for command_name in docker k3d kubectl helm curl; do
  if ! require_command "${command_name}"; then
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  cat >&2 <<'EOF'

Install the missing tools, then rerun:
  make cluster-prereqs

Standard local cluster tool choices:
  docker   - container runtime for k3d nodes
  k3d      - laptop Kubernetes distribution
  kubectl  - Kubernetes client
  helm     - add-on/package manager
  curl     - smoke-test HTTP ingress
EOF
  exit 1
fi

print_step "Tool versions"
docker --version
k3d version
kubectl version --client=true
helm version --short

print_step "Checking Docker daemon"
docker info >/dev/null
echo "Docker is reachable."
