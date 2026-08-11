# Apps Network Policy Smoke Test Policies

This directory contains test-only `NetworkPolicy` manifests for proving policy enforcement in the `apps` namespace.

These policies are paired with the temporary smoke workload in:

```text
../../../network-policy-smoke-test.yaml
```

They model common application traffic paths without claiming to be the final `apps` namespace policy set:

```text
allow-ingress-controller.yaml   Traefik ingress controller to exposed app pods.
allow-frontend-to-backend.yaml  Frontend pods to backend pods.
allow-backend-to-database.yaml  Backend pods to database pods.
allow-external-egress.yaml      Selected pods to external HTTP/HTTPS endpoints.
```

## Expected Labels

Ingress-exposed pods should opt in with:

```text
platformone.io/expose=ingress
```

Application flow policies use standard Kubernetes app labels:

```text
app.kubernetes.io/part-of=shopease
app.kubernetes.io/component=frontend
app.kubernetes.io/component=backend
app.kubernetes.io/component=database
```

Pods that require controlled external egress should opt in with:

```text
platformone.io/egress=external
```

These policies are not applied by default. Validate the expected traffic path before enabling them with the baseline default-deny policy.

## Smoke Test Workflow

Run the smoke workflow from the local-lab repository root:

```bash
make network-policies-smoke-policies-apply
make network-policies-smoke-policies-verify
make network-policies-smoke-apply
make network-policies-smoke-verify
make network-policies-smoke-delete
```
