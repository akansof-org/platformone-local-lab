# Access Services Locally Runbook

Status: draft, not yet tested end to end.

This runbook describes how to access services in the local k3d cluster through the default k3s Traefik ingress controller using stable `*.platformone.local` hostnames over HTTP.

## Scope

- Cluster: k3d using k3s.
- Ingress controller: default k3s Traefik.
- DNS: hosts-file based `*.platformone.local`.
- TLS: HTTP-only for the current local baseline.
- Current HTTP port: `8080`, based on `k3d/cluster-dev.k3d.yaml`.

## Mental Model

The request path is:

```text
browser/curl
  -> test.platformone.local resolves to 127.0.0.1
  -> 127.0.0.1:8080 reaches the k3d load balancer
  -> Traefik receives the request
  -> Traefik matches a Kubernetes Ingress host
  -> Kubernetes Service routes to ready Pods
```

If any step breaks, the common symptoms are DNS errors, connection refused, Traefik `404`, or `503`.

## One-Time Laptop DNS Setup

Add stable local names to the laptop hosts file.

macOS/Linux:

```text
/etc/hosts
```

Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

Initial local hostname entries:

```text
127.0.0.1 test.platformone.local
127.0.0.1 shopease.platformone.local
127.0.0.1 argocd.platformone.local
```

Verify resolution on macOS:

```bash
dscacheutil -q host -a name test.platformone.local
```

Expected result: `test.platformone.local` resolves to `127.0.0.1`.

## Verify Cluster And Traefik

Confirm the cluster exists:

```bash
k3d cluster list
```

Confirm nodes are ready:

```bash
kubectl get nodes
```

Confirm Traefik pods are running:

```bash
kubectl -n kube-system get pods | grep -i traefik
```

Confirm the Traefik service exists:

```bash
kubectl -n kube-system get svc | grep -i traefik
```

## Verify Laptop-To-Cluster Ingress

The current k3d config maps laptop HTTP port `8080` to cluster port `80`.

Check the configured mapping:

```bash
grep -n "8080:80" k3d/cluster-dev.k3d.yaml
```

Check whether something responds on the local ingress port:

```bash
curl -I http://127.0.0.1:8080
```

Expected result: some HTTP response. A `404` is acceptable before any ingress route exists. Connection refused usually means the cluster is not running or the k3d load balancer is not exposing the port.

If the local standard later changes to host port `80`, update `k3d/cluster-dev.k3d.yaml`, this runbook, and the cluster lifecycle validation script together.

## Deploy A Smoke Test Route

Goal:

```text
http://test.platformone.local:8080
```

The standard smoke manifest is:

```text
manifests/smoke-test.yaml
```

It creates:

- A `smoke-echo` Deployment using `traefik/whoami:v1.10.1`.
- A `smoke-echo` Service.
- A `smoke-echo` Ingress for `test.platformone.local`.

Apply it from the local-lab repository root:

```bash
make smoke-apply
```

Confirm the pod:

```bash
kubectl get pods -l app=smoke-echo
```

After applying the resources, verify the ingress object:

```bash
kubectl get ingress smoke-echo
```

Expected result: an Ingress exists with host `test.platformone.local`.

Test from the laptop:

```bash
curl -i http://test.platformone.local:8080
```

To test Traefik host routing without relying on the hosts file:

```bash
curl -i -H "Host: test.platformone.local" http://127.0.0.1:8080
```

Expected result: HTTP `200` from the test app after the pod and endpoints are ready.

Expected body: output from `traefik/whoami`, including request headers and pod/container information.

Optional cleanup:

```bash
make smoke-delete
```

## Troubleshooting

### DNS Does Not Resolve

Symptom:

```text
Could not resolve host
```

Checks:

```bash
dscacheutil -q host -a name test.platformone.local
```

Fix:

- Add or correct the hosts-file entry.
- Confirm it points to `127.0.0.1`.

### Connection Refused

Meaning: the hostname resolves, but nothing is listening on the expected local port.

Checks:

```bash
k3d cluster list
curl -I http://127.0.0.1:8080
```

Fix:

- Start or recreate the k3d cluster.
- Confirm `k3d/cluster-dev.k3d.yaml` maps `8080:80` to the load balancer.

### Traefik 404

Meaning: Traefik is reachable, but no ingress route matched the request host/path.

Checks:

```bash
kubectl get ingress -A
kubectl describe ingress -n <namespace> <ingress-name>
```

Fix:

- Confirm the Ingress host is exactly `test.platformone.local`.
- Confirm the Ingress points to the correct Service name and port.

### Traefik 503

Meaning: Traefik matched the route, but the backend is unhealthy or unreachable.

Checks:

```bash
kubectl get pods -n <namespace>
kubectl get svc,endpoints -n <namespace>
```

Fix:

- Confirm pods are ready.
- Confirm Service selectors match pod labels.
- Confirm Service `targetPort` matches the app container port.

## Rebuild Test

After deleting and recreating the cluster:

1. Hosts-file entries should remain unchanged on the laptop.
2. Traefik should return to `Running`.
3. Smoke manifests or GitOps bootstrap should be reapplied.
4. `curl -i http://test.platformone.local:8080` should return HTTP `200`.

If this fails, update:

- The cluster create config.
- The ingress exposure assumptions.
- The smoke test manifests.
- This runbook.

## Evidence To Capture

Useful proof for the local access workflow:

```bash
kubectl -n kube-system get pods | grep -i traefik
kubectl get ingress -A
curl -i http://test.platformone.local:8080
curl -i -H "Host: test.platformone.local" http://127.0.0.1:8080
```

## Validation Status

This runbook is not complete until the smoke route has been applied and tested after a cluster rebuild.
