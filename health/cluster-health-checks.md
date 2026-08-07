# Cluster Health Checks

PlatformOne validates the local k3d cluster through layered health checks. The checks prove that the control plane, core add-ons, DNS, ingress, and local persistent storage are usable before product workloads are treated as meaningful.

## Health Targets

| Domain | What it proves |
| --- | --- |
| API access | `kubectl` can reach the local Kubernetes API server. |
| Node health | k3d server and agent nodes are `Ready`. |
| Core add-ons | CoreDNS, Traefik, metrics-server, and local-path provisioner are available. |
| Cluster DNS | Pods can resolve Kubernetes service names. |
| Ingress | Traefik can route HTTP traffic through the k3d load balancer. |
| Storage | PVCs bind and data survives pod recreation when the PVC is retained. |

## Health Tiers

Quick check:

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

Standard check:

```bash
make cluster-verify
```

Full local foundation check:

```bash
make cluster-health
```

## Standard Cluster Verification

`make cluster-verify` is the primary baseline health command.

It checks:

- Current Kubernetes context.
- Node readiness.
- Core `kube-system` deployments.
- Cluster DNS resolution.
- Temporary ingress route through Traefik on `127.0.0.1:8080`.

The validation script creates a temporary namespace named `cluster-smoke` and removes it before exit.

## Full Health Workflow

`make cluster-health` runs the baseline check plus the reusable ingress and storage smoke tests.

Workflow:

```text
cluster-verify
  -> smoke-delete
  -> smoke-apply
  -> smoke-verify
  -> smoke-delete
  -> storage-delete
  -> storage-apply
  -> storage-verify
  -> storage-restart
  -> storage-verify
  -> storage-delete
```

The ingress smoke test uses:

```text
manifests/smoke-test.yaml
```

The storage smoke test uses:

```text
manifests/storage-smoke-test.yaml
```

## Workload Health Boundary

Cluster health checks validate the local platform foundation. Product workload checks are separate.

Cluster health examples:

```bash
make cluster-verify
make cluster-health
```

Product workload examples:

```bash
kubectl get pods -n apps
curl -i http://shopease.platformone.local:8080
```

## Failure Signals

| Symptom | Likely area |
| --- | --- |
| `kubectl` cannot connect | Kubeconfig, k3d cluster state, or API port mapping |
| Nodes are not `Ready` | k3d node containers or k3s startup |
| CoreDNS unavailable | Cluster DNS |
| Traefik unavailable | Local ingress |
| Ingress smoke returns `404` | Ingress host/path mismatch |
| Ingress smoke returns `503` | Backend Service endpoints or pod readiness |
| PVC stays `Pending` | StorageClass or local-path provisioner |
| PVC data disappears after pod recreation | PVC wiring, namespace, or accidental PVC deletion |

## Fix Or Reset

Fix in place when:

- A pod is still starting.
- A manifest has a typo.
- A hosts-file entry is missing.
- An image reference or tag is wrong.
- A smoke resource from a previous run needs cleanup.

Recreate the cluster when:

- k3d node containers are unhealthy.
- Core `kube-system` components remain broken after normal waits.
- k3d port mappings changed.
- Kubernetes or k3s version changed.
- The goal is to prove the environment can be rebuilt from source-controlled config.

Reset command:

```bash
make cluster-reset
```
