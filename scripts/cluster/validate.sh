#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_command kubectl
require_command curl

SMOKE_NAMESPACE="${SMOKE_NAMESPACE:-cluster-smoke}"
SMOKE_HOST="${SMOKE_HOST:-cluster-smoke.localhost}"
SMOKE_URL="${SMOKE_URL:-http://127.0.0.1:8080}"

cleanup_smoke() {
  kubectl delete namespace "${SMOKE_NAMESPACE}" --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup_smoke EXIT

print_step "Cluster context"
kubectl config current-context

print_step "Nodes"
kubectl get nodes -o wide
kubectl wait --for=condition=Ready nodes --all --timeout=120s

print_step "Core pods"
kubectl get pods -n kube-system
wait_for_kube_system_deployment coredns
wait_for_kube_system_deployment local-path-provisioner
wait_for_kube_system_deployment metrics-server
wait_for_kube_system_deployment traefik

print_step "DNS smoke test"
kubectl create namespace "${SMOKE_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl run dns-check \
  --namespace "${SMOKE_NAMESPACE}" \
  --image busybox:1.36 \
  --restart Never \
  --command -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-check -n "${SMOKE_NAMESPACE}" --timeout=60s
kubectl exec -n "${SMOKE_NAMESPACE}" dns-check -- nslookup kubernetes.default.svc.cluster.local

print_step "Ingress smoke test"
kubectl create deployment web \
  --namespace "${SMOKE_NAMESPACE}" \
  --image nginx:1.27 \
  --port 80
kubectl expose deployment web \
  --namespace "${SMOKE_NAMESPACE}" \
  --port 80 \
  --target-port 80
kubectl create ingress web \
  --namespace "${SMOKE_NAMESPACE}" \
  --class traefik \
  --rule "${SMOKE_HOST}/=web:80"
kubectl wait --for=condition=Available deployment/web -n "${SMOKE_NAMESPACE}" --timeout=120s

for attempt in {1..30}; do
  if curl --fail --silent --show-error --header "Host: ${SMOKE_HOST}" "${SMOKE_URL}" >/dev/null; then
    echo "Ingress reached ${SMOKE_HOST} through ${SMOKE_URL}."
    exit 0
  fi
  sleep 2
done

echo "Ingress smoke test failed: ${SMOKE_HOST} was not reachable through ${SMOKE_URL}." >&2
exit 1
