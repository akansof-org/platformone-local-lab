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
```

The current managed namespace set is `platformone-system`, `observability`, `security`, `gitops`, `apps`, and `sandbox`.

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
