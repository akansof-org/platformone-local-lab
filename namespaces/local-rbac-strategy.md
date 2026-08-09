# Local RBAC Strategy

PlatformOne uses namespace-scoped Kubernetes RBAC to model platform access boundaries in the local k3d cluster.

The current checked-in RBAC manifests implement the pattern for the `apps` namespace. The same role and binding structure should be repeated for the remaining managed namespaces.

## RBAC Manifests

The RBAC manifests are organized by namespace, then split by resource type:

```text
manifests/rbac/
└── apps/
    ├── roles.yaml
    └── rolebindings.yaml
```

Apply and verify it from the local-lab repository root. The apply target uses recursive apply so future namespace folders under `manifests/rbac/` are included automatically.

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

Platform engineering should receive viewer access across managed namespaces for operational visibility.

## Implemented Reference Namespace

The `apps` namespace is the reference implementation.

It includes:

- `Role/platformone-namespace-admin`
- `Role/platformone-namespace-editor`
- `Role/platformone-namespace-viewer`
- `RoleBinding/apps-admin`
- `RoleBinding/apps-platform-engineering-viewer`

Bindings:

| Binding | Subject | Role |
| --- | --- | --- |
| `apps-admin` | `platformone:product-engineering` | `platformone-namespace-admin` |
| `apps-platform-engineering-viewer` | `platformone:platform-engineering` | `platformone-namespace-viewer` |

## Replication Pattern

To extend this to another namespace:

1. Create a folder under `manifests/rbac/` using the namespace name.
2. Copy `apps/roles.yaml` into the new folder.
3. Copy `apps/rolebindings.yaml` into the new folder.
4. Change `metadata.namespace` to the target namespace in both files.
5. Update RoleBinding names and subject groups for the namespace owner.
6. Run `make rbac-apply`.
7. Run `make rbac-verify`.

## Verification

Current verification lists RBAC resources in the implemented namespace:

```bash
kubectl get role,rolebinding -n apps
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
