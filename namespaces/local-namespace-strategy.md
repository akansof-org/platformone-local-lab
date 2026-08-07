# Local Namespace Strategy

PlatformOne uses a small set of purpose-based Kubernetes namespaces in the local k3d cluster. Namespaces are applied from a source-controlled manifest and labelled consistently so platform-managed namespaces can be identified quickly.

## Namespace Manifest

The namespace manifest is:

```text
manifests/platform-namespaces.yaml
```

Apply and verify it from the local-lab repository root:

```bash
make namespaces-apply
make namespaces-verify
```

## Namespace Model

| Namespace | Purpose |
| --- | --- |
| `platformone-system` | Core platform services and platform-owned controllers. |
| `observability` | Metrics, logs, dashboards, tracing, and alerting tools. |
| `security` | Policy, scanning, admission, and security tooling. |
| `gitops` | GitOps controllers and related delivery automation. |
| `apps` | Product workloads during local development. |
| `sandbox` | Temporary experiments, learning workloads, and throwaway tests. |

The older `platformone` namespace may exist in a local cluster from previous bootstrap work, but it is not part of the managed namespace baseline. New platform-owned workloads should use the purpose-based namespaces above.

## Labels

Every managed namespace has these labels:

```text
platformone.io/managed-by=platformone-local-lab
platformone.io/environment=local
platformone.io/purpose=<purpose>
```

Current purpose values:

| Namespace | `platformone.io/purpose` |
| --- | --- |
| `platformone-system` | `platform-core` |
| `observability` | `observability` |
| `security` | `security` |
| `gitops` | `gitops` |
| `apps` | `product-workloads` |
| `sandbox` | `experiments` |

## Verification

`make namespaces-verify` confirms the expected namespaces exist and then lists namespaces managed by the local lab label:

```bash
kubectl get namespaces --show-labels | grep 'platformone.io/managed-by=platformone-local-lab'
```

A healthy local namespace baseline includes:

```text
apps
gitops
observability
platformone-system
sandbox
security
```

## Workload Placement

| Workload type | Namespace |
| --- | --- |
| Platform controllers and internal platform services | `platformone-system` |
| Argo CD or equivalent GitOps tooling | `gitops` |
| Metrics, logging, tracing, dashboards, alerting | `observability` |
| Policy engines, scanners, security automation | `security` |
| Product workloads and demos | `apps` |
| Temporary experiments | `sandbox` |

Default Kubernetes namespaces such as `default`, `kube-system`, `kube-public`, and `kube-node-lease` are left to Kubernetes and k3s.
