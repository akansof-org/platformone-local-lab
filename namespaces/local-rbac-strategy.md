# Local RBAC Strategy

PlatformOne uses namespace-scoped Kubernetes RBAC to model platform access boundaries in the local k3d cluster.

The checked-in RBAC manifests implement the namespace RBAC pattern for all managed platform namespaces.

## RBAC Manifests

The RBAC manifests are organized by namespace, then split by resource type:

```text
manifests/rbac/
├── apps/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── gitops/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── observability/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── platformone-system/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── sandbox/
│   ├── roles.yaml
│   └── rolebindings.yaml
└── security/
    ├── roles.yaml
    └── rolebindings.yaml
```

Apply and verify it from the local-lab repository root. The apply target uses recursive apply so namespace folders under `manifests/rbac/` are included automatically.

```bash
make rbac-apply
make rbac-verify
```

## Role Model

| Role | Purpose |
| --- | --- |
| `platformone-namespace-admin` | Full namespace administration for the namespace owner. |
| `platformone-namespace-editor` | Manage normal workload resources without managing RBAC. |
| `platformone-namespace-viewer` | Read-only visibility into namespace resources, events, and pod logs. |

The RBAC model is namespace-scoped. It does not grant cluster-admin access.

## Group Model

Kubernetes subjects use group names that can later map to real identity-provider groups:

```text
platformone:platform-engineering
platformone:sre
platformone:security-engineering
platformone:product-engineering
```

RBAC does not provide authentication by itself. It only defines what an authenticated user or group can do once Kubernetes receives their identity.

## Namespace Ownership Bindings

| Namespace | Admin group |
| --- | --- |
| `platformone-system` | `platformone:platform-engineering` |
| `observability` | `platformone:sre` |
| `security` | `platformone:security-engineering` |
| `gitops` | `platformone:platform-engineering` |
| `apps` | `platformone:product-engineering` |
| `sandbox` | `platformone:platform-engineering` |

Platform engineering receives operational visibility across managed namespaces. Non-platform-owned namespaces use an explicit viewer binding. Platform-owned namespaces grant the same group admin access, so a separate viewer binding would be redundant.

## Implemented Bindings

Each managed namespace includes the standard role set:

| Namespace | Binding | Subject | Role |
| --- | --- | --- | --- |
| `apps` | `apps-admin` | `platformone:product-engineering` | `platformone-namespace-admin` |
| `apps` | `apps-platform-engineering-viewer` | `platformone:platform-engineering` | `platformone-namespace-viewer` |
| `observability` | `observability-sre-admin` | `platformone:sre` | `platformone-namespace-admin` |
| `observability` | `observability-platform-engineering-viewer` | `platformone:platform-engineering` | `platformone-namespace-viewer` |
| `security` | `security-security-engineering-admin` | `platformone:security-engineering` | `platformone-namespace-admin` |
| `security` | `security-platform-engineering-viewer` | `platformone:platform-engineering` | `platformone-namespace-viewer` |
| `gitops` | `gitops-admin` | `platformone:platform-engineering` | `platformone-namespace-admin` |
| `platformone-system` | `platformone-system-admin` | `platformone:platform-engineering` | `platformone-namespace-admin` |
| `sandbox` | `sandbox-admin` | `platformone:platform-engineering` | `platformone-namespace-admin` |

## Verification

Current verification lists RBAC resources in all managed namespaces:

```bash
kubectl get role,rolebinding -n apps
kubectl get role,rolebinding -n observability
kubectl get role,rolebinding -n security
kubectl get role,rolebinding -n gitops
kubectl get role,rolebinding -n platformone-system
kubectl get role,rolebinding -n sandbox
```

## TODO

Add an `rbac-can-i` workflow after local identity and group simulation are defined.

The future target should validate expected authorization behavior with commands such as:

```bash
kubectl auth can-i get pods -n apps --as-group=platformone:product-engineering
kubectl auth can-i create deployments -n apps --as-group=platformone:product-engineering
kubectl auth can-i create rolebindings -n apps --as-group=platformone:platform-engineering
```

This is intentionally not a Make target yet because meaningful `can-i` checks need a clear local identity simulation model.
