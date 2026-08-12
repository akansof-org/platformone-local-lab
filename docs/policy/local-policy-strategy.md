# Local Policy Strategy

PlatformOne uses Kyverno as the local admission policy engine for Kubernetes resource governance.

Policies start in audit mode. Audit mode allows resources to be created while reporting violations. After the policy is tuned and validated, selected policies can be promoted to enforce mode.

## Policy Engine

Kyverno is the local policy engine because it uses Kubernetes-native YAML and has a clear audit-to-enforce workflow.

Kyverno is installed into a dedicated namespace:

```text
kyverno
```

The namespace is separate from `security` because Kyverno should not be co-located with unrelated applications or platform tools.

The local install uses Kyverno's standard non-production Helm install with webhook failure policy forced to `Ignore`. This keeps the laptop cluster usable if Kyverno is restarting while policies are still being introduced in audit mode.

## Manifest Layout

```text
manifests/policies/
├── README.md
├── kyverno/
│   ├── audit/
│   │   ├── disallow-latest-image-tag.yaml
│   │   ├── require-standard-labels.yaml
│   │   └── require-workload-resources.yaml
│   └── enforce/
│       └── README.md
└── smoke-tests/
    ├── bad-deployment-latest-image.yaml
    ├── bad-deployment-missing-labels.yaml
    ├── bad-deployment-no-resources.yaml
    └── good-deployment.yaml
```

## Audit Policies

| Policy | Purpose |
| --- | --- |
| `require-workload-resources` | Requires CPU and memory requests and limits. |
| `disallow-latest-image-tag` | Reports images that omit a tag or use `latest`. |
| `require-standard-labels` | Requires standard app and PlatformOne ownership labels. |

The starter policies target the `apps` and `sandbox` namespaces.

## Operation

Install and verify Kyverno:

```bash
make kyverno-install
make kyverno-verify
```

Apply audit policies:

```bash
make policy-audit-apply
make policy-audit-verify
```

Run smoke fixtures:

```bash
make policy-smoke-apply
make policy-reports
make policy-smoke-delete
```

In audit mode, the bad smoke deployments are created successfully, but Kyverno should report violations.

## Promotion To Enforce

Promote a policy only after:

- audit findings are understood
- false positives are resolved
- smoke tests exist
- local platform-owned workloads comply
- the rule is valuable enough to block deployment

To promote, copy the policy from `kyverno/audit/` to `kyverno/enforce/` and change each validation rule:

```yaml
failureAction: Audit
```

to:

```yaml
failureAction: Enforce
```
