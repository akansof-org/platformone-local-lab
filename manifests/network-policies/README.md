# Network Policies

This directory stores Kubernetes `NetworkPolicy` manifests for the local PlatformOne cluster.

The policy tree separates baseline security posture, shared platform traffic, and namespace-owned workload flows.

```text
baseline/     Shared default posture for managed namespaces.
platform/     Cross-namespace traffic used by platform services.
namespaces/   Namespace-specific application and tooling traffic.
```

The current starter policy is:

```text
baseline/default-deny-ingress.yaml
```

It is intentionally not wired into a Make target yet. Apply network policies only after the expected allow rules and smoke tests are defined.

The detailed local strategy lives in:

```text
../../networking/local-network-policy-strategy.md
```
