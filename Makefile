SHELL := /usr/bin/env bash

.PHONY: cluster-prereqs cluster-up cluster-verify cluster-down cluster-reset cluster-health smoke-apply smoke-verify smoke-delete storage-apply storage-verify storage-restart storage-delete

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
