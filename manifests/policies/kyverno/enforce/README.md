# Enforced Policies

Policies are promoted here only after they have passed audit-mode validation.

Promotion criteria:

- audit findings are understood
- false positives are resolved
- smoke tests exist
- local platform-owned workloads comply
- the rule is important enough to block deployment

When promoting a policy, copy it from `../audit/` and change each validation rule from:

```yaml
failureAction: Audit
```

to:

```yaml
failureAction: Enforce
```
