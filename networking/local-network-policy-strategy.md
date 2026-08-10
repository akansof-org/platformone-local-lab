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

## Rollout Posture

Network policies are not connected to a Make target yet.

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
