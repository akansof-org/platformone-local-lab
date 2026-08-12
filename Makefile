SHELL := /usr/bin/env bash

.PHONY: cluster-prereqs cluster-up cluster-verify cluster-down cluster-reset cluster-health smoke-apply smoke-verify smoke-delete storage-apply storage-verify storage-restart storage-delete namespaces-apply namespaces-verify guardrails-apply guardrails-verify rbac-apply rbac-verify kyverno-install kyverno-verify policy-audit-apply policy-audit-verify policy-reports policy-smoke-apply policy-smoke-delete network-policies-smoke-policies-apply network-policies-smoke-policies-verify network-policies-smoke-apply network-policies-smoke-verify network-policies-smoke-delete

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
	kubectl apply -f manifests/smoke-test.yaml

smoke-verify:
	kubectl get pods -l app=smoke-echo
	kubectl get ingress smoke-echo
	curl -i -H "Host: test.platformone.local" http://127.0.0.1:8080

smoke-delete:
	kubectl delete -f manifests/smoke-test.yaml --ignore-not-found=true

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
