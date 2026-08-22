SHELL := /usr/bin/env bash

.PHONY: cluster-prereqs cluster-up cluster-verify cluster-down cluster-reset cluster-health smoke-apply smoke-verify smoke-delete storage-apply storage-verify storage-restart storage-delete namespaces-apply namespaces-verify guardrails-apply guardrails-verify rbac-apply rbac-verify ingress-verify cert-manager-install cert-manager-verify cert-manager-remove cert-manager-recover cert-manager-smoke-apply cert-manager-smoke-verify cert-manager-smoke-delete metrics-server-install metrics-server-verify metrics-server-remove metrics-server-recover kyverno-install kyverno-verify kyverno-remove kyverno-recover argocd-install argocd-verify argocd-password argocd-port-forward argocd-remove argocd-recover platform-components-install platform-components-verify platform-components-remove platform-components-recover policy-audit-apply policy-audit-verify policy-reports policy-smoke-apply policy-smoke-delete network-policies-smoke-policies-apply network-policies-smoke-policies-verify network-policies-smoke-apply network-policies-smoke-verify network-policies-smoke-delete

cluster-prereqs:
	./scripts/cluster/prereqs.sh

cluster-up:
	./scripts/cluster/create.sh

cluster-verify:
	./scripts/cluster/validate.sh

cluster-down:
	./scripts/cluster/destroy.sh

cluster-reset:
	./scripts/cluster/reset.sh

cluster-health: cluster-verify
	-$(MAKE) smoke-delete
	$(MAKE) smoke-apply
	$(MAKE) smoke-verify
	$(MAKE) smoke-delete
	-$(MAKE) storage-delete
	$(MAKE) storage-apply
	$(MAKE) storage-verify
	$(MAKE) storage-restart
	$(MAKE) storage-verify
	$(MAKE) storage-delete

smoke-apply:
	kubectl apply -f manifests/ingress-smoke-test.yaml

smoke-verify:
	kubectl get pods -l app=smoke-echo
	kubectl get ingress smoke-echo
	curl -i -H "Host: test.platformone.local" http://127.0.0.1:8080

smoke-delete:
	kubectl delete -f manifests/ingress-smoke-test.yaml --ignore-not-found=true

storage-apply:
	kubectl apply -f manifests/storage-smoke-test.yaml

storage-verify:
	kubectl get storageclass
	kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/storage-smoke-pvc --timeout=120s
	kubectl wait --for=condition=Ready pod/storage-smoke-pod --timeout=120s
	kubectl get pvc storage-smoke-pvc
	kubectl get pod storage-smoke-pod
	kubectl exec storage-smoke-pod -- cat /data/hello.txt

storage-restart:
	kubectl delete pod storage-smoke-pod --ignore-not-found=true --wait=true
	kubectl apply -f manifests/storage-smoke-test.yaml

storage-delete:
	kubectl delete -f manifests/storage-smoke-test.yaml --ignore-not-found=true

PLATFORM_NAMESPACES := platformone-system observability security gitops apps sandbox

namespaces-apply:
	kubectl apply -f manifests/platform-namespaces.yaml

namespaces-verify:
	@for ns in $(PLATFORM_NAMESPACES); do \
		kubectl get namespace $$ns >/dev/null || exit 1; \
	done
	kubectl get namespaces --show-labels | grep 'platformone.io/managed-by=platformone-local-lab'

guardrails-apply:
	kubectl apply -f manifests/resource-guardrails/

guardrails-verify:
	kubectl get resourcequota -n platformone-system
	kubectl get resourcequota -n observability
	kubectl get resourcequota -n security
	kubectl get resourcequota -n gitops
	kubectl get resourcequota -n apps
	kubectl get resourcequota -n sandbox
	kubectl get limitrange -n platformone-system
	kubectl get limitrange -n observability
	kubectl get limitrange -n security
	kubectl get limitrange -n gitops
	kubectl get limitrange -n apps
	kubectl get limitrange -n sandbox

rbac-apply:
	kubectl apply -R -f manifests/rbac/

rbac-verify:
	kubectl get role,rolebinding -n apps
	kubectl get role,rolebinding -n observability
	kubectl get role,rolebinding -n security
	kubectl get role,rolebinding -n gitops
	kubectl get role,rolebinding -n platformone-system
	kubectl get role,rolebinding -n sandbox

ingress-verify:
	kubectl get deployment traefik -n kube-system
	kubectl -n kube-system rollout status deployment/traefik --timeout=120s
	kubectl get ingressclass

cert-manager-install:
	helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager --version v1.20.3 --namespace cert-manager --create-namespace --set crds.enabled=true

cert-manager-verify:
	kubectl get namespace cert-manager
	kubectl -n cert-manager rollout status deployment/cert-manager --timeout=180s
	kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --timeout=180s
	kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=180s
	kubectl get crd certificates.cert-manager.io
	kubectl get crd issuers.cert-manager.io
	kubectl get crd clusterissuers.cert-manager.io

cert-manager-remove:
	helm uninstall cert-manager -n cert-manager --ignore-not-found

cert-manager-recover: cert-manager-install cert-manager-verify

cert-manager-smoke-apply:
	kubectl apply -f manifests/cert-manager-smoke-test.yaml
	kubectl wait --for=condition=Ready certificate/cert-manager-smoke-cert -n sandbox --timeout=120s

cert-manager-smoke-verify:
	kubectl get clusterissuer platformone-selfsigned-smoke
	kubectl get certificate cert-manager-smoke-cert -n sandbox
	kubectl get certificaterequest -n sandbox
	kubectl get secret cert-manager-smoke-tls -n sandbox

cert-manager-smoke-delete:
	kubectl delete -f manifests/cert-manager-smoke-test.yaml --ignore-not-found=true

metrics-server-install:
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
	helm repo update
	helm upgrade --install metrics-server metrics-server/metrics-server --namespace kube-system --values helm-values/metrics-server/k3d-local.yaml

metrics-server-verify:
	kubectl get deployment metrics-server -n kube-system
	kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
	kubectl get apiservice v1beta1.metrics.k8s.io
	kubectl top nodes

metrics-server-remove:
	helm uninstall metrics-server -n kube-system --ignore-not-found

metrics-server-recover: metrics-server-install metrics-server-verify

kyverno-install:
	helm repo add kyverno https://kyverno.github.io/kyverno/
	helm repo update
	helm upgrade --install kyverno kyverno/kyverno --namespace kyverno --create-namespace --set config.webhooks.forceFailurePolicyIgnore.enabled=true

kyverno-verify:
	kubectl get namespace kyverno
	kubectl get pods -n kyverno
	kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
	kubectl -n kyverno rollout status deployment/kyverno-background-controller --timeout=180s
	kubectl -n kyverno rollout status deployment/kyverno-cleanup-controller --timeout=180s
	kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
	kubectl get crd clusterpolicies.kyverno.io
	kubectl get crd policyreports.wgpolicyk8s.io

kyverno-remove:
	helm uninstall kyverno -n kyverno --ignore-not-found

kyverno-recover: kyverno-install kyverno-verify policy-audit-apply

argocd-install:
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	helm upgrade --install argocd argo/argo-cd --namespace gitops --create-namespace --values helm-values/argocd/local.yaml

argocd-verify:
	kubectl get namespace gitops
	kubectl get pods -n gitops
	kubectl -n gitops rollout status deployment/argocd-server --timeout=180s
	kubectl -n gitops rollout status deployment/argocd-repo-server --timeout=180s
	kubectl -n gitops rollout status deployment/argocd-redis --timeout=180s
	kubectl -n gitops rollout status statefulset/argocd-application-controller --timeout=180s

argocd-password:
	@echo "ArgoCD initial admin password:"
	@kubectl get secret argocd-initial-admin-secret -n gitops -o jsonpath="{.data.password}" | base64 --decode; echo

argocd-port-forward:
	kubectl port-forward svc/argocd-server -n gitops 8081:443

argocd-remove:
	helm uninstall argocd -n gitops --ignore-not-found

argocd-recover: argocd-install argocd-verify

platform-components-install: cert-manager-install metrics-server-install kyverno-install

platform-components-verify: ingress-verify cert-manager-verify metrics-server-verify kyverno-verify namespaces-verify guardrails-verify rbac-verify

platform-components-remove: cert-manager-remove metrics-server-remove kyverno-remove

platform-components-recover: platform-components-install platform-components-verify policy-audit-apply

policy-audit-apply:
	kubectl apply -f manifests/policies/kyverno/audit/

policy-audit-verify:
	kubectl get clusterpolicy

policy-reports:
	kubectl get policyreport -A
	kubectl get clusterpolicyreport

policy-smoke-apply:
	kubectl apply -f manifests/policies/smoke-tests/

policy-smoke-delete:
	kubectl delete -f manifests/policies/smoke-tests/ --ignore-not-found=true

network-policies-smoke-policies-apply:
	kubectl apply -f manifests/network-policies/baseline/default-deny-ingress.yaml
	kubectl apply -f manifests/network-policies/smoke-tests/apps/allow-ingress-controller.yaml
	kubectl apply -f manifests/network-policies/smoke-tests/apps/allow-frontend-to-backend.yaml
	kubectl apply -f manifests/network-policies/smoke-tests/apps/allow-backend-to-database.yaml
	kubectl apply -f manifests/network-policies/smoke-tests/apps/allow-external-egress.yaml

network-policies-smoke-policies-verify:
	kubectl get networkpolicy -n apps

network-policies-smoke-apply:
	kubectl apply -f manifests/network-policy-smoke-test.yaml
	kubectl -n apps rollout status deployment/netpol-backend --timeout=120s
	kubectl -n apps rollout status deployment/netpol-database --timeout=120s
	kubectl wait --for=condition=Ready pod/netpol-frontend-client -n apps --timeout=120s
	kubectl wait --for=condition=Ready pod/netpol-backend-client -n apps --timeout=120s
	kubectl wait --for=condition=Ready pod/netpol-blocked-client -n apps --timeout=120s

network-policies-smoke-verify:
	kubectl exec -n apps netpol-frontend-client -- wget -qO- -T 5 http://netpol-backend.apps.svc.cluster.local
	! kubectl exec -n apps netpol-blocked-client -- wget -qO- -T 5 http://netpol-backend.apps.svc.cluster.local
	kubectl exec -n apps netpol-backend-client -- sh -c "printf 'PING\r\n' | nc -w 5 netpol-database.apps.svc.cluster.local 6379 | grep PONG"
	! kubectl exec -n apps netpol-blocked-client -- sh -c "printf 'PING\r\n' | nc -w 5 netpol-database.apps.svc.cluster.local 6379 | grep PONG"

network-policies-smoke-delete:
	kubectl delete -f manifests/network-policy-smoke-test.yaml --ignore-not-found=true
