# Local Registry Strategy

PlatformOne uses a hybrid image workflow for the laptop Kubernetes cluster.

The cluster is local `k3d`, but the platform direction is AWS. The strategy therefore has two supported paths:

- Fast local development: build locally, then import the image into k3d.
- AWS-realistic proof and release flow: build, push to Amazon ECR, then let the local cluster pull with an `imagePullSecret`.

## Decision

Default dev loop:

```text
docker build -> k3d image import -> deploy local image
```

Release/proof loop:

```text
docker build -> docker push to ECR -> deploy ECR image with imagePullSecret
```

Use local import for speed and learning. Use ECR when the goal is CI/CD, GitOps, AWS artifact flow, or portfolio evidence.

## Naming And Tagging

### Local Dev Images

Use service-level names with a `dev` tag:

```text
shopease/cartservice:dev
platformone/<service>:dev
```

Recommended manifest settings for local imports:

```yaml
image: shopease/cartservice:dev
imagePullPolicy: IfNotPresent
```

`IfNotPresent` works well for imported images because k3d already has the image loaded into the node runtime.

### ECR Images

Use full ECR image references:

```text
<account>.dkr.ecr.<region>.amazonaws.com/shopease/cartservice:<tag>
```

Use unique tags for deterministic proof:

```text
gitsha-<shortsha>
0.1.0-<shortsha>
```

Do not rely on `latest` for anything that needs to be repeatable.

## Workflow A: Local Dev With k3d Import

Use this path for fast iteration, spikes, debugging, and learning loops.

Example for ShopEase `cartservice`:

```bash
cd ../../10-downloads/shopease/src/cartservice/src
docker build -t shopease/cartservice:dev .
k3d image import shopease/cartservice:dev -c dev
```

Deploy manifests that reference:

```yaml
image: shopease/cartservice:dev
imagePullPolicy: IfNotPresent
```

If the workload is already running, restart it so Kubernetes creates a new pod from the imported image:

```bash
kubectl rollout restart deployment/cartservice -n apps
kubectl rollout status deployment/cartservice -n apps
```

Proof checklist:

- Make a visible code or response change.
- Build the image with the `:dev` tag.
- Import it into `k3d`.
- Redeploy or restart the workload.
- Confirm the changed behavior appears in the app or logs.

Common pitfall:

- Rebuilding locally does not update k3d by itself. Re-import after every rebuild.

## Workflow B: AWS ECR Release/Proof

Use this path for AWS-realistic delivery, CI/CD demonstrations, GitOps evidence, and release candidates.

Prereqs for this path:

- AWS CLI installed.
- Valid AWS credentials for the target account.
- ECR repository created for the service.
- Docker authenticated to ECR for the current session.

Set these values for the current AWS account and region:

```bash
export AWS_ACCOUNT_ID="<account>"
export AWS_REGION="<region>"
export SERVICE="cartservice"
export IMAGE_TAG="gitsha-<shortsha>"
export ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/shopease/${SERVICE}"
```

Authenticate Docker to ECR:

```bash
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
```

Build, tag, and push:

```bash
docker build -t "${SERVICE}:${IMAGE_TAG}" .
docker tag "${SERVICE}:${IMAGE_TAG}" "${ECR_REPO}:${IMAGE_TAG}"
docker push "${ECR_REPO}:${IMAGE_TAG}"
```

Create or update the local k3d pull secret in the namespace that will run the workload:

```bash
kubectl create secret docker-registry ecr-pull-secret \
  --namespace apps \
  --docker-server="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "${AWS_REGION}")" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -
```

Reference the ECR image and pull secret in the workload:

```yaml
image: <account>.dkr.ecr.<region>.amazonaws.com/shopease/cartservice:gitsha-<shortsha>
imagePullPolicy: IfNotPresent
imagePullSecrets:
  - name: ecr-pull-secret
```

Proof checklist:

- Push a uniquely tagged image to ECR.
- Deploy the workload using the ECR image reference.
- Confirm the pod reaches `Running`.
- Delete the pod.
- Confirm Kubernetes recreates it and pulls successfully from ECR.

Useful checks:

```bash
kubectl get pods -n apps
kubectl describe pod -n apps <pod-name>
kubectl get events -n apps --sort-by=.lastTimestamp
```

Common pitfalls:

- `ImagePullBackOff` usually means the secret is missing, expired, in the wrong namespace, or the image reference is wrong.
- Reusing tags makes it hard to know whether the cluster is running the new build.
- Local k3d does not inherit AWS IAM permissions from EKS nodes, because it is not running in AWS.

## k3d And EKS Mapping

For the laptop cluster, ECR access is deliberately modeled with a Kubernetes `imagePullSecret`.

Later, when workloads run on EKS, image pulls should move to AWS-native IAM-based access through node roles or the platform's chosen EKS identity model. The local secret is a laptop-cluster bridge, not the final cloud pattern.

## When To Use Each Path

| Situation | Use |
| --- | --- |
| Tight code/debug loop | k3d import |
| Offline local learning | k3d import |
| Demoing deterministic rebuilds | k3d import first, ECR for proof |
| CI/CD or GitOps evidence | ECR |
| AWS delivery rehearsal | ECR |
| Preparing for EKS migration | ECR |

## Completion Gate

This registry strategy is complete when both paths have been demonstrated:

- Local path: build, import, deploy, and observe a visible change.
- ECR path: build, push, deploy, and prove the local cluster can pull with `ecr-pull-secret`.
- Tradeoffs are explainable: k3d import is fastest; ECR is more production-like but requires auth, tagging discipline, and network access.
