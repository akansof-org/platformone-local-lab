# Network Policies

This directory stores Kubernetes `NetworkPolicy` manifests for the local PlatformOne cluster.

The policy tree separates baseline security posture, shared platform traffic, and namespace-owned workload flows.

```text
baseline/     Shared default posture for managed namespaces.
platform/     Cross-namespace traffic used by platform services.
namespaces/   Namespace-specific application and tooling traffic.
smoke-tests/  Temporary policies used only to prove NetworkPolicy behavior.
```

The current starter policy is:

```text
baseline/default-deny-ingress.yaml
```

The current smoke-test policies for the `apps` namespace are:

```text
smoke-tests/apps/allow-ingress-controller.yaml
smoke-tests/apps/allow-frontend-to-backend.yaml
smoke-tests/apps/allow-backend-to-database.yaml
smoke-tests/apps/allow-external-egress.yaml
```

It is intentionally not wired into a Make target yet. Apply network policies only after the expected allow rules and smoke tests are defined.

The detailed local strategy lives in:

```text
../../networking/local-network-policy-strategy.md
```
