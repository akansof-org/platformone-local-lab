# Policy Checks

This directory stores admission policy manifests and smoke-test fixtures for the local PlatformOne cluster.

Policy checks are introduced in audit mode first. Audit mode allows resources to be created while Kyverno records violations in policy reports and admission warnings.

```text
kyverno/audit/      Audit-only policies.
kyverno/enforce/    Future enforced policies promoted after validation.
smoke-tests/        Good and bad resources used to prove policy reporting.
```

Kyverno is installed separately with Helm. The current policy engine namespace is:

```text
kyverno
```

That namespace is intentionally dedicated to Kyverno.
