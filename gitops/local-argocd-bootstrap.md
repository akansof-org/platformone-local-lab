# Local Argo CD Bootstrap

This document describes how Argo CD is installed, accessed, verified, removed,
and recovered in the local PlatformOne k3d lab.

Argo CD is the local GitOps controller for PlatformOne. It runs in the managed
`gitops` namespace and is installed with Helm so the installation can be
replayed after a cluster rebuild.

## Design

| Setting | Value |
| --- | --- |
| Namespace | `gitops` |
| Helm release | `argocd` |
| Helm repository | `https://argoproj.github.io/argo-helm` |
| Chart | `argo/argo-cd` |
| Values file | `helm-values/argocd/local.yaml` |
| Local access model | `kubectl port-forward` |
| Local UI URL | `https://localhost:8081` |

The local install keeps Argo CD internal to the cluster. It is not exposed
through the shared local ingress path by default. This avoids mixing the GitOps
control plane with application ingress while the local platform is still being
built out.

## Values

Local chart overrides live here:

```text
helm-values/argocd/local.yaml
```

The current values enable insecure server mode and set small local resource
requests/limits for the core Argo CD components:

```yaml
configs:
  params:
    server.insecure: true
```

This is a local-only setting. It makes browser access through port-forwarding
simple by allowing the Argo CD server to terminate without requiring a trusted
local certificate chain.

## Install

Apply the managed namespace baseline first:

```bash
make namespaces-apply
make namespaces-verify
```

Install Argo CD:

```bash
make argocd-install
```

The install target adds the Argo Helm repository, updates local Helm metadata,
and installs or upgrades the `argocd` release in the `gitops` namespace.

## Verify

Run:

```bash
make argocd-verify
```

The verification target checks:

- the `gitops` namespace exists;
- Argo CD pods exist in the namespace;
- `argocd-server` is rolled out;
- `argocd-repo-server` is rolled out;
- `argocd-redis` is rolled out;
- `argocd-application-controller` is rolled out as a StatefulSet;

Dex, ApplicationSet, and Notifications are optional for the first local GitOps
delivery path and may be disabled in `helm-values/argocd/local.yaml`.

You can inspect the installed Helm release directly:

```bash
helm status argocd -n gitops
helm list -n gitops
```

## Access The UI

Get the initial admin password:

```bash
make argocd-password
```

Start a local port-forward:

```bash
make argocd-port-forward
```

Open:

```text
https://localhost:8081
```

Use:

```text
username: admin
password: value printed by make argocd-password
```

The browser may show a certificate warning because this is a local control-plane
service exposed through port-forwarding.

## Access With The CLI

The Argo CD CLI is optional for this local lab, but it is useful for practicing
GitOps operations outside the UI.

With the port-forward running:

```bash
argocd login localhost:8081 --username admin --password <password> --insecure
argocd app list
```

If the CLI is not installed, the Kubernetes and UI workflows are enough for the
current local bootstrap.

## Remove

Remove the Helm release:

```bash
make argocd-remove
```

This removes the Argo CD workloads managed by Helm. The `gitops` namespace is
part of the platform namespace baseline and is intentionally left in place.

## Recover

Reinstall and verify Argo CD:

```bash
make argocd-recover
```

After a full cluster rebuild, run the namespace baseline before recovery:

```bash
make namespaces-apply
make argocd-recover
```

## Operational Notes

- Argo CD runs in `gitops`, separate from application workloads.
- Local UI access uses port `8081` because port `8080` is reserved for local
  ingress traffic in the k3d cluster profile.
- The current Make target installs the chart version resolved from the local
  Helm repository metadata. Pin the chart version in `make argocd-install`
  when the lab needs fully deterministic Argo CD rebuilds.
- Future GitOps manifests should be kept separate from this runbook. A common
  next structure is `gitops/projects/` for `AppProject` resources and
  `gitops/applications/` for `Application` resources.
- If Argo CD components fail to start because of namespace quotas, see
  `gitops/argocd-quota-troubleshooting.md`.

## Current Validation Commands

```bash
make argocd-install
make argocd-verify
make argocd-password
make argocd-port-forward
make argocd-remove
make argocd-recover
```
