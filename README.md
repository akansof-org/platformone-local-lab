# PlatformOne Local Lab

Local development and demo lab for validating PlatformOne workflows before cloud deployment.

This repository owns the laptop Kubernetes foundation for PlatformOne. The current standard local cluster is a `k3d` cluster named `dev`, created from the checked-in config at:

```text
k3d/cluster-dev.k3d.yaml
```

The goal is simple: the cluster should be rebuildable from source-controlled scripts, not from memory.

## Quick Start

Run all commands from this directory:

```bash
cd 02-platformone/platformone-local-lab
```

Check required tools:

```bash
make cluster-prereqs
```

Create the cluster:

```bash
make cluster-up
```

Verify the cluster:

```bash
make cluster-verify
```

Destroy the cluster:

```bash
make cluster-down
```

Delete, recreate, and verify the cluster:

```bash
make cluster-reset
```

## What This Creates

The standard cluster profile is defined in `k3d/cluster-dev.k3d.yaml`.

| Setting | Value |
| --- | --- |
| Cluster name | `dev` |
| Kubernetes context | `k3d-dev` |
| Distribution | `k3d` / `k3s` |
| Servers | `1` |
| Agents | `2` |
| Kubernetes image | `rancher/k3s:v1.35.2-k3s1` |
| API endpoint | `127.0.0.1:6445` |
| HTTP ingress | `127.0.0.1:8080` |
| HTTPS ingress | `127.0.0.1:8443` |
| Local registry | `registry.localhost:7445` |

The create workflow also creates these baseline namespaces:

```text
platformone
platformone-system
observability
apps
```

## Required Tools

The lifecycle scripts expect:

| Tool | Purpose |
| --- | --- |
| Docker | Runs the local k3d node and registry containers. |
| k3d | Creates and manages the laptop Kubernetes cluster. |
| kubectl | Validates and operates the cluster. |
| helm | Reserved for add-on installs and future bootstrap work. |
| curl | Verifies local ingress reachability. |

Use `make cluster-prereqs` to verify the tools and print their versions.

## Make Targets

| Target | What it does |
| --- | --- |
| `make cluster-prereqs` | Verifies required commands and Docker daemon access. |
| `make cluster-up` | Creates the `dev` cluster from `k3d/cluster-dev.k3d.yaml`; exits cleanly if it already exists. |
| `make cluster-verify` | Runs node, core pod, DNS, and ingress smoke checks. |
| `make cluster-health` | Runs baseline, ingress, and storage health checks. |
| `make namespaces-apply` | Applies the local platform namespace baseline. |
| `make namespaces-verify` | Verifies the managed namespace labels and expected namespaces. |
| `make guardrails-apply` | Applies ResourceQuota and LimitRange guardrails. |
| `make guardrails-verify` | Verifies namespace resource guardrails. |
| `make rbac-apply` | Applies the namespace RBAC scaffold. |
| `make rbac-verify` | Verifies the implemented RBAC resources. |
| `make ingress-verify` | Verifies the built-in Traefik ingress controller. |
| `make cert-manager-install` | Installs cert-manager with Helm. |
| `make cert-manager-verify` | Verifies cert-manager controllers and CRDs. |
| `make cert-manager-remove` | Uninstalls the cert-manager Helm release. |
| `make metrics-server-install` | Installs Metrics Server with Helm. |
| `make metrics-server-verify` | Verifies Metrics Server and `kubectl top nodes`. |
| `make metrics-server-remove` | Uninstalls the Metrics Server Helm release. |
| `make kyverno-install` | Installs Kyverno into its dedicated namespace. |
| `make kyverno-verify` | Verifies Kyverno namespace, pods, and CRDs. |
| `make kyverno-remove` | Uninstalls the Kyverno Helm release. |
| `make platform-components-install` | Installs the Helm-managed minimum platform components. |
| `make platform-components-verify` | Verifies the minimum platform component set. |
| `make platform-components-remove` | Removes Helm-managed platform components. |
| `make platform-components-recover` | Reinstalls and verifies Helm-managed platform components, then reapplies audit policies. |
| `make policy-audit-apply` | Applies audit-mode Kyverno policies. |
| `make policy-audit-verify` | Lists installed Kyverno ClusterPolicies. |
| `make policy-reports` | Lists Kyverno policy reports. |
| `make policy-smoke-apply` | Applies good and bad policy smoke fixtures. |
| `make policy-smoke-delete` | Deletes policy smoke fixtures. |
| `make cluster-down` | Deletes the `dev` k3d cluster while preserving runtime data for inspection. |
| `make cluster-reset` | Deletes, recreates, and validates the cluster. |

## Script Layout

```text
scripts/cluster/
├── lib.sh
├── prereqs.sh
├── create.sh
├── validate.sh
├── destroy.sh
└── reset.sh
```

The `Makefile` is the normal operator interface. The scripts can also be run directly when debugging.

## Runtime Data

Runtime files are kept outside this repository, under the workspace-level `09-runtime` directory:

| Path | Purpose |
| --- | --- |
| `../../09-runtime/kubeconfigs` | Dedicated generated kubeconfigs. |
| `../../09-runtime/generated-config` | Generated local configuration files. |
| `../../09-runtime/local-registry/k3d-dev` | Local registry storage. |

`make cluster-down` preserves these directories. This is intentional, because they can be useful when debugging cluster lifecycle problems.

To rebuild while clearing PlatformOne runtime data:

```bash
CLEAN_RUNTIME=1 make cluster-reset
```

## Registry Strategy

PlatformOne uses a hybrid image workflow for the local k3d cluster:

- Fast dev path: build locally, then import the image into k3d with `k3d image import`.
- AWS proof path: build, push to Amazon ECR, then let the local cluster pull with an `imagePullSecret`.

The detailed strategy lives in:

```text
registry/local-registry-strategy.md
```

Short version:

```bash
docker build -t shopease/cartservice:dev .
k3d image import shopease/cartservice:dev -c dev
```

Use ECR when you need AWS-realistic CI/CD, GitOps, or portfolio evidence. Because k3d is local and not EKS, ECR pulls require a namespace-local Kubernetes image pull secret such as `ecr-pull-secret`.

The ECR path also requires the AWS CLI and valid AWS credentials for the target account and region.

## Namespace Strategy

The local platform namespace baseline is defined in:

```text
manifests/platform-namespaces.yaml
```

The detailed namespace strategy lives in:

```text
namespaces/local-namespace-strategy.md
```

Apply and verify it with:

```bash
make namespaces-apply
make namespaces-verify
```

Managed local namespaces are labelled with:

```text
platformone.io/managed-by=platformone-local-lab
platformone.io/environment=local
platformone.io/owner=<owner>
```

The current managed namespace set is `platformone-system`, `observability`, `security`, `gitops`, `apps`, and `sandbox`.

## Resource Guardrails

The local platform resource guardrails are defined in:

```text
manifests/resource-guardrails/
```

The guardrail manifests are split by resource type:

```text
manifests/resource-guardrails/resourcequotas.yaml
manifests/resource-guardrails/limitranges.yaml
```

The detailed guardrail strategy lives in:

```text
namespaces/local-resource-guardrails.md
```

Apply and verify them with:

```bash
make guardrails-apply
make guardrails-verify
```

The guardrails use `ResourceQuota` for namespace-level caps and `LimitRange` for container and PVC defaults/bounds.

## RBAC Strategy

The local RBAC scaffold is defined in:

```text
manifests/rbac/
├── apps/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── gitops/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── observability/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── platformone-system/
│   ├── roles.yaml
│   └── rolebindings.yaml
├── sandbox/
│   ├── roles.yaml
│   └── rolebindings.yaml
└── security/
    ├── roles.yaml
    └── rolebindings.yaml
```

The detailed RBAC strategy lives in:

```text
namespaces/local-rbac-strategy.md
```

Apply and verify it with:

```bash
make rbac-apply
make rbac-verify
```

The current manifests implement the RBAC pattern for all managed platform namespaces. `make rbac-apply` applies the RBAC tree recursively.

## Platform Components

The minimum local platform component set is documented in:

```text
platform/local-platform-components.md
```

The set intentionally stays small:

```text
Ingress
cert-manager
Metrics Server
Kyverno
Namespace standards
Local registry integration
```

Install and verify the Helm-managed components with:

```bash
make platform-components-install
make platform-components-verify
```

The component runbook records ownership, removal, and recovery for each platform component.

## Policy Strategy

The local policy engine is Kyverno. Kyverno is installed into a dedicated namespace:

```text
kyverno
```

Audit-mode policies are defined in:

```text
manifests/policies/kyverno/audit/
```

The detailed policy strategy lives in:

```text
docs/policy/local-policy-strategy.md
```

Install Kyverno, apply audit policies, and inspect reports with:

```bash
make kyverno-install
make kyverno-verify
make policy-audit-apply
make policy-audit-verify
make policy-smoke-apply
make policy-reports
make policy-smoke-delete
```

Audit mode allows resources to be created while Kyverno reports violations. Policies are promoted to enforce mode only after findings are understood, false positives are resolved, smoke tests exist, and local platform workloads comply.

## Network Policy Strategy

The local network policy manifests are organized by policy responsibility:

```text
manifests/network-policies/
├── baseline/
│   └── default-deny-ingress.yaml
├── platform/
├── smoke-tests/
│   └── apps/
└── namespaces/
    ├── apps/
    ├── gitops/
    ├── observability/
    ├── sandbox/
    └── security/
```

The detailed network policy strategy lives in:

```text
networking/local-network-policy-strategy.md
```

The baseline policy defines default-deny ingress for the managed platform namespaces. The app-specific allow policies currently live under `smoke-tests/apps/` because they exist to prove NetworkPolicy behavior, not to model a real application yet.

## Storage Strategy

The local cluster uses the default k3s `local-path` StorageClass for development-grade PVC behavior.

The detailed strategy lives in:

```text
storage/local-storage-strategy.md
```

The reusable storage smoke manifest lives in:

```text
manifests/storage-smoke-test.yaml
```

Run it with:

```bash
make storage-apply
make storage-verify
make storage-restart
make storage-verify
make storage-delete
```

PVC data is expected to survive pod recreation when the PVC is retained. Data is treated as disposable across full k3d cluster deletion unless it is backed up separately.

## DNS And TLS Strategy

The local environment uses stable hostnames with HTTP-only ingress:

```text
*.platformone.local
```

The default laptop mapping is:

```text
127.0.0.1 test.platformone.local
127.0.0.1 shopease.platformone.local
```

The detailed strategy lives in:

```text
networking/local-dns-tls-strategy.md
```

The draft access runbook lives in:

```text
networking/access-services-locally-runbook.md
```

The reusable Traefik smoke manifest lives in:

```text
manifests/smoke-test.yaml
```

Apply it with:

```bash
make smoke-apply
make smoke-verify
make smoke-delete
```

The current local baseline deliberately avoids HTTPS and certificate trust setup. A planned enhancement will introduce a local CA plus cert-manager for `*.platformone.local`.

## Validation Details

`make cluster-verify` creates a temporary namespace named `cluster-smoke`, then removes it when validation exits.

It proves:

- The active Kubernetes context is reachable.
- All nodes are `Ready`.
- Core `kube-system` deployments are available.
- DNS resolves `kubernetes.default.svc.cluster.local`.
- A temporary NGINX app is reachable through Traefik ingress on `http://127.0.0.1:8080`.

The ingress smoke host is:

```text
cluster-smoke.localhost
```

The validation script sends the host header directly with `curl`, so no manual `/etc/hosts` change is required for this smoke test.

## Cluster Health Checks

The local lab has three health-check tiers:

```bash
kubectl get nodes
kubectl get pods -n kube-system
make cluster-verify
make cluster-health
```

The detailed health runbook lives in:

```text
health/cluster-health-checks.md
```

`make cluster-health` runs the baseline cluster verification, the Traefik ingress smoke test, and the local storage smoke test.

## Updating The Cluster

For durable changes, edit source-controlled config or scripts, then recreate the cluster.

| Change | Preferred workflow |
| --- | --- |
| Add or remove worker nodes | Edit `agents` in `k3d/cluster-dev.k3d.yaml`, then run `make cluster-reset`. |
| Change API or ingress ports | Edit `kubeAPI` or `ports`, then run `make cluster-reset`. |
| Upgrade Kubernetes/k3s | Edit the `image` tag, then run `make cluster-reset`. |
| Add required namespaces | Update `scripts/cluster/create.sh`, then run `make cluster-reset`. |
| Add required add-ons | Add scripted or GitOps-managed install steps, then run `make cluster-reset`. |

Use in-place cluster changes only for short experiments. If the change should survive a rebuild, capture it in this repo.

## Cleanup

Delete only the PlatformOne local cluster:

```bash
make cluster-down
```

Recreate it from scratch:

```bash
make cluster-reset
```

Clear PlatformOne runtime data during reset:

```bash
CLEAN_RUNTIME=1 make cluster-reset
```

Broader Docker cleanup is deliberately manual because it can affect unrelated local projects:

```bash
docker system prune
```

Use that only when you intentionally want Docker to remove unused resources beyond this cluster.

## Troubleshooting

Check the current context:

```bash
kubectl config current-context
```

List k3d clusters:

```bash
k3d cluster list
```

Inspect nodes:

```bash
kubectl get nodes -o wide
```

Inspect core pods:

```bash
kubectl get pods -n kube-system
```

If `make cluster-verify` fails on ingress immediately after a deployment, rerun it once. A brief `503` can happen while Traefik discovers the temporary smoke service.

If Docker is not reachable, confirm Docker Desktop or the Docker daemon is running, then rerun:

```bash
make cluster-prereqs
```

## Documentation

The fuller local cluster lifecycle runbook lives in:

```text
../platformone-docs/docs/engineering/local-cluster-lifecycle.md
```

## Ownership

Primary owner: `@akansof-org/platformone`

SRE reviews lab changes that affect operational workflows, observability, or incident exercises.
