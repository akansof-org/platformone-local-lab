# Implementation Guidance Spec

This spec defines how Codex should guide implementation work in the PlatformOne local lab when the goal is for the engineer to learn by doing.

The default collaboration style is:

```text
explain the intent -> point to the right files -> describe what to add -> let the engineer implement -> review and validate
```

## When To Use This Mode

Use this mode when the engineer says or implies:

- "I want to do this myself."
- "Guide me."
- "Help me understand where this goes."
- "What should I look for?"
- "Let's plan before touching code."

Do not jump straight to implementation in those cases. Start with orientation and implementation guidance.

## Guidance Shape

For each implementation item, explain:

1. What the item is trying to accomplish.
2. What existing repo pattern it should follow.
3. Which files or folders to inspect first.
4. Which new files should be created, if any.
5. Which existing files should be updated.
6. What commands should be run for validation.
7. What "done" looks like.

Prefer this structure:

```text
What you are building
Where to look
Where to place it
What to add
How to validate
How to know it is done
```

## File Placement Guidance

When introducing a new platform capability, point the engineer to the existing ownership pattern:

```text
helm-values/              Helm values for local installs.
manifests/                Kubernetes resources applied directly.
platform/                 Platform component inventory and runbooks.
networking/               DNS, TLS, ingress, and NetworkPolicy strategy.
namespaces/               Namespace, RBAC, quotas, and guardrail strategy.
docs/                     Local-lab supporting documentation.
../platformone-docs/docs/ Public engineering documentation mirror.
Makefile                  Operator interface for repeatable workflows.
```

If the capability is Helm-managed, prefer:

```text
helm-values/<component>/local.yaml
```

If the capability is a Kubernetes smoke test, prefer:

```text
manifests/<component>-smoke-test.yaml
```

If the capability has several test-only manifests, prefer:

```text
manifests/<area>/smoke-tests/<scenario>/
```

If the capability is part of the platform inventory, update:

```text
platform/local-platform-components.md
```

## Make Target Guidance

When proposing Make targets, group them around the lifecycle:

```text
<component>-install
<component>-verify
<component>-remove
<component>-recover
<component>-smoke-apply
<component>-smoke-verify
<component>-smoke-delete
```

Use `make -n` as the first validation step for Makefile changes.

Do not add broad apply targets for risky controls until the specific smoke path is clear. This is especially important for:

- NetworkPolicy
- admission policies
- RBAC
- cluster-wide controllers

## Review Mode

When the engineer implements the files, Codex should review by checking:

- Does the implementation match the documented pattern?
- Are names, namespaces, labels, and owners consistent?
- Does `roleRef`, `issuerRef`, or equivalent object reference resolve by Kubernetes rules?
- Are Make targets scoped and reversible?
- Are docs describing the actual solution, not a planning checklist?
- Are smoke tests meaningful now, not only future placeholders?

Validation should include the lowest-risk checks first:

```bash
ruby -e 'require "yaml"; Dir["**/*.yaml", "**/*.yml"].each { |f| YAML.load_stream(File.read(f)) }; puts "YAML OK"'
make -n <target>
git diff --check
```

Use live `kubectl` or `helm` commands only when the engineer asks to validate against the cluster or when live validation is clearly required.

## Explanation Style

Keep explanations engineer-friendly:

- Start with the purpose.
- Use the repo's current folders and naming.
- Give concrete examples.
- Explain the Kubernetes resolution model when references are involved.
- Separate "current local lab" from "future production/EKS" behavior.
- Call out what is intentionally deferred.

Avoid presenting roadmap language as if it were implementation state. The docs should describe what exists, how to operate it, and what is explicitly not enabled yet.

## Done Criteria

An implementation item is done when it has:

- source-controlled manifests, values, scripts, or docs
- Make targets if repeatable operation is expected
- ownership and recovery notes if it is a platform component
- a smoke or verification path when practical
- local validation output
- public docs updates when the feature should be visible outside the repo

If live validation fails because the local cluster is unhealthy, report that separately from repo implementation status:

```text
Repo implementation: complete
Live validation: blocked by <specific cluster condition>
```
