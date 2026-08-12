# Local Platform Components

PlatformOne keeps the local k3d platform intentionally small. The goal is to install only the controllers required for local routing, certificates, metrics, policy checks, namespace standards, and local image workflows.

## Minimum Platform Set

| Component | Namespace/location | Owner | Install model | Purpose |
| --- | --- | --- | --- | --- |
| Ingress | `kube-system` | `platform-engineering` | Built into k3s as Traefik | Routes local HTTP traffic to Services. |
| cert-manager | `cert-manager` | `platform-engineering` | Helm | Provides certificate automation for future local TLS. |
| Metrics Server | `kube-system` | `sre` | Helm | Enables Kubernetes resource metrics and `kubectl top`. |
| Kyverno | `kyverno` | `security-engineering` | Helm | Runs audit-first admission policy checks. |
| Namespace standards | Cluster-scoped and managed namespaces | `platform-engineering` | Kubernetes manifests | Defines namespace labels, ownership, RBAC, and resource guardrails. |
| Local registry integration | k3d registry and image workflows | `platform-engineering` | k3d + Docker/ECR workflows | Supports fast local image import and AWS-like ECR pull flows. |

Do not install broader platform components such as GitOps controllers, observability stacks, secret managers, or service mesh until the minimum set is stable.

## Operation

Install the Helm-managed platform components:

```bash
make platform-components-install
```

Verify the minimum platform set:

```bash
make platform-components-verify
```

Recover the Helm-managed platform components:

```bash
make platform-components-recover
```

## Proof Tests

The minimum platform set has two proof tests:

| Test | Purpose | Commands |
| --- | --- | --- |
| Policy violation | Proves Kyverno reports bad workloads in audit mode. | `make policy-smoke-apply`, `make policy-reports`, `make policy-smoke-delete` |
| Namespace isolation | Proves NetworkPolicy allows expected app traffic and denies unexpected traffic. | `make network-policies-smoke-policies-apply`, `make network-policies-smoke-apply`, `make network-policies-smoke-verify`, `make network-policies-smoke-delete` |

Run policy smoke tests only after Kyverno is healthy:

```bash
make kyverno-verify
make policy-audit-apply
make policy-smoke-apply
make policy-reports
make policy-smoke-delete
```

Run namespace-isolation smoke tests after the `apps` namespace exists:

```bash
make namespaces-verify
make network-policies-smoke-policies-apply
make network-policies-smoke-policies-verify
make network-policies-smoke-apply
make network-policies-smoke-verify
make network-policies-smoke-delete
```

## Component Runbooks

### Ingress

Local ingress uses the default Traefik controller installed by k3s.

Verify:

```bash
make ingress-verify
make smoke-apply
make smoke-verify
make smoke-delete
```

Removal:

Do not manually remove Traefik in the local lab. It is part of the k3s cluster profile.

Recovery:

```bash
make cluster-reset
```

### cert-manager

cert-manager is installed with Helm from the official cert-manager chart.

Install:

```bash
make cert-manager-install
```

Verify:

```bash
make cert-manager-verify
```

Remove:

```bash
make cert-manager-remove
```

Recovery:

```bash
make cert-manager-recover
```

Notes:

- The local install enables cert-manager CRD management through Helm.
- The current local DNS/TLS strategy is still HTTP-first; cert-manager is installed as the certificate foundation for future TLS work.

### Metrics Server

Metrics Server is installed with Helm from the official Kubernetes SIGs chart.

Install:

```bash
make metrics-server-install
```

Verify:

```bash
make metrics-server-verify
```

Remove:

```bash
make metrics-server-remove
```

Recovery:

```bash
make metrics-server-recover
```

Local k3d note:

```text
helm-values/metrics-server/k3d-local.yaml
```

sets `--kubelet-insecure-tls` because local clusters commonly use kubelet serving certificates that do not satisfy normal Metrics Server TLS validation. Do not carry this setting into production.

### Kyverno

Kyverno owns audit-first admission policy checks.

Install:

```bash
make kyverno-install
```

Verify:

```bash
make kyverno-verify
```

Remove:

```bash
make kyverno-remove
```

Recovery:

```bash
make kyverno-recover
make policy-audit-apply
```

Notes:

- The local install forces Kyverno webhook failure policy to `Ignore` while policies are being introduced in audit mode.
- If Kyverno is unhealthy, stabilize it before relying on `policy-smoke-apply`.

### Namespace Standards

Namespace standards are source-controlled Kubernetes manifests.

Apply and verify:

```bash
make namespaces-apply
make namespaces-verify
make guardrails-apply
make guardrails-verify
make rbac-apply
make rbac-verify
```

Recovery:

Reapply the namespace, guardrail, and RBAC manifests after cluster rebuild.

### Local Registry Integration

The local registry strategy is hybrid:

```text
fast local loop: build locally -> k3d image import
AWS-like loop: build -> push to ECR -> pull with imagePullSecret
```

Verify:

```bash
docker build -t shopease/cartservice:dev .
k3d image import shopease/cartservice:dev -c dev
```

Recovery:

Recreate the k3d cluster and registry, then recreate any namespace-local pull secrets used for ECR testing.
