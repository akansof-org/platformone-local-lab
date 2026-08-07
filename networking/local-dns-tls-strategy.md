# Local DNS And TLS Strategy

PlatformOne services in the local k3d environment use stable `*.platformone.local` hostnames and HTTP ingress through the default k3s Traefik controller.

The current local baseline is intentionally HTTP-only. Local HTTPS will be added later as a platform capability using a local certificate authority and cert-manager.

## Decisions

| Area | Decision |
| --- | --- |
| Local domain | `*.platformone.local` |
| Name resolution | Laptop hosts-file entries |
| Hosts target | `127.0.0.1` |
| Ingress controller | Default k3s Traefik |
| HTTP exposure | `127.0.0.1:8080` to cluster port `80` |
| HTTPS exposure | Reserved as `127.0.0.1:8443` to cluster port `443` |
| Current TLS posture | HTTP-only |
| Planned TLS posture | Local CA plus cert-manager |

## Local Addressing Model

The k3d cluster is configured in `k3d/cluster-dev.k3d.yaml`.

Ingress traffic follows this path:

```text
Browser or curl
  -> *.platformone.local resolves to 127.0.0.1
  -> 127.0.0.1:8080 reaches the k3d load balancer
  -> Traefik receives the request
  -> Traefik matches a Kubernetes Ingress host
  -> Kubernetes Service routes to ready Pods
```

Local service URLs use HTTP and the configured ingress port:

```text
http://test.platformone.local:8080
http://shopease.platformone.local:8080
```

## Hosts File Entries

Local DNS is managed with laptop hosts-file entries.

macOS/Linux:

```text
/etc/hosts
```

Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

Baseline entries:

```text
127.0.0.1 test.platformone.local
127.0.0.1 shopease.platformone.local
127.0.0.1 argocd.platformone.local
127.0.0.1 grafana.platformone.local
```

Any local service that is opened repeatedly should have a stable `*.platformone.local` hostname.

## Hostname Standards

Platform service names:

```text
argocd.platformone.local
grafana.platformone.local
prometheus.platformone.local
alertmanager.platformone.local
kyverno.platformone.local
backstage.platformone.local
```

Product service names:

```text
shopease.platformone.local
mastermeds.platformone.local
finvault.platformone.local
carebridge.platformone.local
transroute.platformone.local
gridsense.platformone.local
```

Additional local environment suffixes, such as `*.local.platformone.local` or `*.homelab.platformone.local`, are not part of the current local baseline.

## Smoke Route

The standard local HTTP smoke route uses:

```text
test.platformone.local
```

The reusable manifest is:

```text
manifests/smoke-test.yaml
```

It creates a `traefik/whoami` Deployment, Service, and Ingress for `test.platformone.local`.

Apply and verify from the local-lab repository root:

```bash
make smoke-apply
make smoke-verify
```

Remove it with:

```bash
make smoke-delete
```

Direct host-routing verification, without relying on the hosts file:

```bash
curl -i -H "Host: test.platformone.local" http://127.0.0.1:8080
```

Hostname verification, after the hosts-file entry exists:

```bash
curl -i http://test.platformone.local:8080
```

## Troubleshooting

If `test.platformone.local` does not resolve, check the hosts file:

```bash
dscacheutil -q host -a name test.platformone.local
```

If `127.0.0.1:8080` refuses connections, check the cluster and k3d port mapping:

```bash
k3d cluster list
grep -n "8080:80" k3d/cluster-dev.k3d.yaml
curl -I http://127.0.0.1:8080
```

If Traefik returns `404`, check the Ingress host and route:

```bash
kubectl get ingress -A
kubectl describe ingress -n <namespace> <ingress-name>
```

If Traefik returns `503`, check backend readiness:

```bash
kubectl get pods -n <namespace>
kubectl get svc,endpoints -n <namespace>
```

## TLS Position

The current local baseline does not terminate TLS at ingress.

Local services use:

```text
http://<service>.platformone.local:8080
```

The cluster config reserves `8443` for future HTTPS ingress, but certificates, issuers, and laptop trust configuration are not currently implemented.

## Planned HTTPS Design

The planned local HTTPS design will add:

- A local certificate authority trusted by the laptop.
- cert-manager in the cluster.
- A local issuer or cluster issuer.
- Certificates for `*.platformone.local` or individual service hostnames.
- HTTPS ingress for selected platform and product services.

Until that design is implemented and validated, local ingress should be described as HTTP-only.
