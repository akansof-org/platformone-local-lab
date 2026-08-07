# Local Storage Strategy

PlatformOne uses the default k3s `local-path` provisioner for development-grade persistent storage in the local k3d cluster.

The storage model is intentionally simple: it provides real Kubernetes `StorageClass`, `PersistentVolume`, and `PersistentVolumeClaim` behavior for local development, demos, and manifest validation, without introducing distributed storage.

## Decisions

| Area                        | Decision                                          |
| --------------------------- | ------------------------------------------------- |
| Default StorageClass        | `local-path`                                    |
| Provisioner                 | k3s local-path provisioner                        |
| Persistence target          | Development-grade persistence                     |
| Pod restart behavior        | Data should remain available through the same PVC |
| Deployment rollout behavior | Data should remain available through the same PVC |
| Cluster deletion behavior   | Data is disposable unless explicitly backed up    |
| Production durability claim | None                                              |

## Storage Model

The local cluster uses dynamic provisioning through the default `local-path` StorageClass.

Workloads request storage with a PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 128Mi
```

Kubernetes binds the PVC to a local-path-backed PV. Pods mount the PVC through `persistentVolumeClaim`.

## Supported Use Cases

Good fits:

- Local stateful workload demos.
- Postgres, Redis, or similar local development dependencies.
- Helm chart and manifest validation for workloads that require PVCs.
- Application-level backup and restore practice.

Not a fit:

- Data that must survive k3d cluster deletion.
- Production durability claims.
- Replication, multi-node storage guarantees, or failure-domain testing.

## Operational Expectations

| Event                           | Expected result                               |
| ------------------------------- | --------------------------------------------- |
| Container restart               | Data persists through the mounted PVC         |
| Pod deletion and recreation     | Data persists if the same PVC is reused       |
| Deployment rollout              | Data persists if the same PVC is reused       |
| k3d node container restart      | Data usually persists, but should be verified |
| k3d cluster delete and recreate | Data is not guaranteed to persist             |

## Inspection Commands

Use these commands to inspect the current storage state:

```bash
kubectl get storageclass
kubectl get pvc -A
kubectl get pv
```

Expected local baseline:

- A default StorageClass exists, normally `local-path`.
- PVCs can reach `Bound`.
- PVs are created dynamically for PVC-backed workloads.

## Storage Smoke Test

The reusable smoke manifest is:

```text
manifests/storage-smoke-test.yaml
```

It creates:

- A `storage-smoke-pvc` PVC requesting `128Mi`.
- A `storage-smoke-pod` BusyBox pod that writes `/data/hello.txt` to the mounted PVC.

Run the test from the local-lab repository root:

```bash
make storage-apply
make storage-verify
```

Recreate the pod while preserving the PVC:

```bash
make storage-restart
make storage-verify
```

Remove the smoke resources:

```bash
make storage-delete
```

## Troubleshooting

If the PVC stays `Pending`, inspect the StorageClass and provisioner:

```bash
kubectl get storageclass
kubectl describe pvc storage-smoke-pvc
kubectl -n kube-system get pods | grep -i local-path
```

If the pod starts but the file is missing after recreation, inspect the pod and PVC wiring:

```bash
kubectl describe pod storage-smoke-pod
kubectl get pvc storage-smoke-pvc
```

Common causes:

- The pod uses `emptyDir` instead of a PVC.
- The pod references the wrong PVC name.
- The pod runs in a different namespace from the PVC.
- The PVC was deleted during cleanup.
