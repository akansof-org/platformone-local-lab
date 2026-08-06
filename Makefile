SHELL := /usr/bin/env bash

.PHONY: cluster-prereqs cluster-up cluster-verify cluster-down cluster-reset

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
