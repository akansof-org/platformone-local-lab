# Local Network Policy Strategy

PlatformOne uses Kubernetes `NetworkPolicy` manifests to define namespace traffic boundaries in the local k3d cluster.

The current network policy work is scaffolded but not applied by default. This avoids accidentally breaking local development traffic before the expected allow rules and smoke tests are in place.

## Manifest Layout

Network policies are stored under:

```text
manifests/network-policies/
```

The directory follows an organization-friendly ownership model:

```text
manifests/network-policies/
├── baseline/
│   └── default-deny-ingress.yaml
├── platform/
├── smoke-tests/
│   └── apps/
└── namespaces/
    ├── apps/
    ├── gitops/
    ├── observability/
    ├── sandbox/
    └── security/
```

## Ownership Model

| Directory | Purpose | Typical owner |
| --- | --- | --- |
| `baseline/` | Shared default posture for managed namespaces. | Platform/security engineering |
| `platform/` | Cross-namespace traffic required by platform services. | Platform engineering |
| `namespaces/<namespace>/` | Namespace-specific application and tooling traffic. | Namespace owner |
| `smoke-tests/` | Temporary policies used to prove policy enforcement behavior. | Platform engineering |

## Current Policy

The starter policy is:

```text
manifests/network-policies/baseline/default-deny-ingress.yaml
```

It creates a `default-deny-ingress` policy for each managed namespace:

```text
platformone-system
observability
security
gitops
apps
sandbox
```

The policy selects all pods in each namespace and denies inbound traffic unless another `NetworkPolicy` explicitly allows it.

## Apps Smoke Test Policies

The current `apps` policies are test-only and live under the smoke-test area:

```text
manifests/network-policies/smoke-tests/apps/
├── allow-ingress-controller.yaml
├── allow-frontend-to-backend.yaml
├── allow-backend-to-database.yaml
└── allow-external-egress.yaml
```

These policies model common product workload flows:

| Policy | Traffic allowed |
| --- | --- |
| `allow-ingress-controller` | Traefik in `kube-system` to pods labelled `platformone.io/expose=ingress`. |
| `allow-frontend-to-backend` | ShopEase frontend pods to ShopEase backend pods on HTTP ports. |
| `allow-backend-to-database` | ShopEase backend pods to database pods on PostgreSQL and Redis ports. |
| `allow-external-egress` | Opted-in pods to external HTTP/HTTPS endpoints, excluding private RFC1918 ranges. |

The app policies rely on workload labels. Workloads must opt into the intended traffic path with labels such as:

```text
platformone.io/expose=ingress
platformone.io/egress=external
app.kubernetes.io/part-of=shopease
app.kubernetes.io/component=frontend
app.kubernetes.io/component=backend
app.kubernetes.io/component=database
```

## Rollout Posture

General network policy rollout is not connected to a broad Make target yet. The only network policy Make targets are for the explicit smoke workflow.

Before applying baseline deny policies, define and validate the required allow policies for:

- ingress controller traffic into application namespaces
- DNS egress if egress deny policies are introduced
- observability scraping
- GitOps controller access
- security scanning and policy webhooks
- application-to-application flows

## Operating Notes

Start with ingress deny policies before egress deny policies. Default-deny egress can quickly break DNS, API calls, telemetry, image access, and developer workflows if the allow rules are incomplete.

Apply policies deliberately with `kubectl apply` only after the expected traffic paths are documented and tested.

## Apps Smoke Test

The local lab includes a temporary smoke workload that gives the `apps` policies something meaningful to enforce:

```text
manifests/network-policy-smoke-test.yaml
```

It creates:

- a backend Deployment and Service
- a Redis-backed database Deployment and Service
- a frontend-labelled client pod
- a backend-labelled client pod
- an unlabeled-for-access blocked client pod

Run the smoke workflow from the local-lab repository root:

```bash
make network-policies-smoke-policies-apply
make network-policies-smoke-policies-verify
make network-policies-smoke-apply
make network-policies-smoke-verify
make network-policies-smoke-delete
```

The verification proves:

| Path | Expected result |
| --- | --- |
| frontend client to backend service | allowed |
| blocked client to backend service | denied |
| backend client to database service | allowed |
| blocked client to database service | denied |

If the denied paths succeed, the cluster is not enforcing `NetworkPolicy` as expected.
