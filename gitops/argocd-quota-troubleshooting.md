# Argo CD Quota Troubleshooting

This note records the troubleshooting path used when the first Argo CD
`Application` was created but Argo CD did not reconcile it.

## Context

We were testing the first GitOps delivery loop:

```text
platformone-gitops repo -> Argo CD Application -> apps namespace workload
```

The test `Application` was created successfully:

```bash
kubectl apply -f applications/smoke-echo-local.yaml
kubectl get application -n gitops
```

But the `Application` initially showed blank sync and health columns, and the
`argocd` CLI could not sync because no Argo CD server address/login context had
been configured.

## Symptoms

The important symptom was not the CLI error. The important symptom was that the
Argo CD `Application` had no useful status.

```text
NAME               SYNC STATUS   HEALTH STATUS
smoke-echo-local
```

Checking Argo CD workloads showed that the control plane was not fully healthy:

```bash
kubectl get pods -n gitops
kubectl get sts,deploy -n gitops
```

The missing critical component was:

```text
argocd-application-controller   0/1
```

Without the application controller, Argo CD can store `Application` objects but
cannot compare desired state, report sync status, or reconcile workloads.

## What Caused It

The `gitops` namespace had ResourceQuota and LimitRange guardrails.

The quota was too small for the Argo CD Helm chart:

```yaml
limits.cpu: "2"
limits.memory: 2Gi
```

The `gitops` LimitRange also defaulted containers without explicit limits to:

```yaml
default:
  cpu: 500m
  memory: 512Mi
```

That meant each Argo CD component could consume `500m/512Mi` of quota even when
the Helm values did not explicitly request that much. The namespace filled up
before Redis, Dex, and the application controller could all be created.

Later, after Argo CD values were reduced, the controller requested less:

```text
requested: limits.cpu=250m,limits.memory=256Mi
```

But the namespace was still at its limit during rollout, so the controller pod
creation continued to fail.

## How We Investigated

Describe the Argo CD controller:

```bash
kubectl describe statefulset argocd-application-controller -n gitops
```

The event showed the direct cause:

```text
pods "argocd-application-controller-0" is forbidden:
exceeded quota: gitops-quota
```

Check namespace events:

```bash
kubectl get events -n gitops --sort-by=.lastTimestamp
```

This showed Redis, Dex, and the application controller all failing pod creation
because the quota was exhausted.

Check live quota:

```bash
kubectl get resourcequota gitops-quota -n gitops -o yaml
```

Check live LimitRange:

```bash
kubectl get limitrange gitops-defaults -n gitops -o yaml
```

Check pod resource usage:

```bash
kubectl get pods -n gitops -o \
  'custom-columns=NAME:.metadata.name,STATUS:.status.phase,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory'
```

The investigation proved the issue was not the test `Application` manifest. The
Argo CD control plane itself was incomplete because namespace guardrails were
blocking pod creation.

## Resolution

The saved guardrails were updated in:

```text
manifests/resource-guardrails/resourcequotas.yaml
manifests/resource-guardrails/limitranges.yaml
```

`gitops-quota` was increased to leave room for Argo CD and rollout overhead:

```yaml
requests.cpu: "3"
requests.memory: 3Gi
limits.cpu: "4"
limits.memory: 4Gi
pods: "20"
```

`gitops-defaults` was reduced so unconfigured containers do not consume the old
large defaults:

```yaml
defaultRequest:
  cpu: 50m
  memory: 64Mi
default:
  cpu: 250m
  memory: 256Mi
```

The local Argo CD Helm values were also adjusted to set explicit small
resources for the required components and avoid relying on LimitRange defaults:

```text
helm-values/argocd/local.yaml
```

The required local components are:

- `argocd-server`
- `argocd-repo-server`
- `argocd-redis`
- `argocd-application-controller`

Optional components such as Dex, ApplicationSet, and Notifications are not
needed for the first local GitOps delivery test.

Apply the fixed guardrails:

```bash
kubectl apply -f manifests/resource-guardrails/
```

Restart the blocked controller after quota headroom exists:

```bash
kubectl rollout restart statefulset/argocd-application-controller -n gitops
```

Verify Argo CD:

```bash
make argocd-verify
kubectl get pods -n gitops
```

Expected result:

```text
argocd-application-controller-0   1/1   Running
argocd-redis-*                    1/1   Running
argocd-repo-server-*              1/1   Running
argocd-server-*                   1/1   Running
```

## Follow-On Finding

Once the application controller became healthy, the test `Application` started
reporting real status:

```text
smoke-echo-local   OutOfSync   Missing
```

That was expected because auto-sync was disabled. After requesting a sync, Argo
CD created the workload resources, but the Deployment was blocked by Kyverno
because the pod template was missing:

```yaml
platformone.io/owner
```

That was a separate policy issue, not the quota problem. It confirmed that the
GitOps path had progressed far enough for admission policy to evaluate the
workload.

## Lessons

- Blank Argo CD `Application` status usually means the controller has not
  processed the object yet.
- Check Argo CD control plane health before debugging the application manifest.
- ResourceQuota failures appear in workload events, not always in Helm output.
- LimitRange defaults count against ResourceQuota, even when the chart did not
  explicitly set those limits.
- Local platform components should have explicit resource requests and limits.
- Namespace quotas need enough headroom for rollout overlap and optional chart
  components.

