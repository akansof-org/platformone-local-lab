# Local Resource Guardrails

PlatformOne uses Kubernetes `ResourceQuota` and `LimitRange` objects to keep local namespaces bounded and predictable.

The guardrails are intentionally development-grade. They protect the laptop cluster from accidental resource sprawl while keeping enough room for platform tooling, product demos, and experiments.

## Guardrail Manifest

The guardrail manifest is:

```text
manifests/platform-resource-guardrails.yaml
```

Apply and verify it from the local-lab repository root:

```bash
make guardrails-apply
make guardrails-verify
```

## Guardrail Model

`ResourceQuota` caps the total resources a namespace can consume.

`LimitRange` sets container defaults and per-object bounds so simple manifests that omit resources still receive predictable requests and limits.

| Namespace | Posture |
| --- | --- |
| `platformone-system` | Conservative defaults for core platform services. |
| `observability` | Higher memory allowance for telemetry tools. |
| `security` | Moderate allowance for policy and scanning tools. |
| `gitops` | Small, predictable controller footprint. |
| `apps` | Moderate product workload capacity. |
| `sandbox` | Strict limits for experiments. |

## Namespace Quotas

| Namespace | Requests CPU | Requests Memory | Limits CPU | Limits Memory | Pods | PVCs | Storage |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `platformone-system` | `2` | `2Gi` | `4` | `4Gi` | `20` | `5` | `10Gi` |
| `observability` | `2` | `3Gi` | `4` | `8Gi` | `25` | `8` | `20Gi` |
| `security` | `2` | `2Gi` | `4` | `4Gi` | `15` | `4` | `8Gi` |
| `gitops` | `1` | `1Gi` | `2` | `2Gi` | `10` | `3` | `5Gi` |
| `apps` | `4` | `6Gi` | `8` | `12Gi` | `40` | `10` | `20Gi` |
| `sandbox` | `1` | `1Gi` | `2` | `2Gi` | `10` | `2` | `2Gi` |

## Default Container Limits

| Namespace | Default request | Default limit | Max per container |
| --- | --- | --- | --- |
| `platformone-system` | `100m`, `128Mi` | `500m`, `512Mi` | `1 CPU`, `1Gi` |
| `observability` | `100m`, `256Mi` | `500m`, `1Gi` | `2 CPU`, `4Gi` |
| `security` | `100m`, `128Mi` | `500m`, `512Mi` | `1 CPU`, `2Gi` |
| `gitops` | `100m`, `128Mi` | `500m`, `512Mi` | `1 CPU`, `1Gi` |
| `apps` | `100m`, `128Mi` | `500m`, `512Mi` | `2 CPU`, `2Gi` |
| `sandbox` | `50m`, `64Mi` | `250m`, `256Mi` | `500m`, `512Mi` |

## PVC Bounds

| Namespace | Min PVC size | Max PVC size |
| --- | --- | --- |
| `platformone-system` | `128Mi` | `5Gi` |
| `observability` | `128Mi` | `10Gi` |
| `security` | `128Mi` | `5Gi` |
| `gitops` | `128Mi` | `5Gi` |
| `apps` | `128Mi` | `10Gi` |
| `sandbox` | `128Mi` | `1Gi` |

## Verification

Inspect all namespace guardrails:

```bash
kubectl get resourcequota -A
kubectl get limitrange -A
```

Inspect one namespace in detail:

```bash
kubectl describe resourcequota -n sandbox
kubectl describe limitrange -n sandbox
```

## Operating Notes

These values are a starting point for the local lab. Increase or decrease them when real local workloads prove that the limits are too loose or too tight.

Do not use these numbers as production sizing guidance. Production quotas should be based on workload profiles, SLOs, tenancy model, and cloud infrastructure constraints.
