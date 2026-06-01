# Convenience targets for the non-GitOps (CI / local) workflow.
#
#   make template SERVER=example-server ENV=qual            # render only
#   make render   SERVER=example-server ENV=qual            # render + resolve Vault
#   make deploy   SERVER=example-server ENV=qual TAG=abc123 # render + resolve + apply
#
# template needs only helm. render/deploy additionally need argocd-vault-plugin
# (and deploy needs oc/kubectl + Vault auth env vars -- see deploy/deploy.sh).

SERVER ?= example-server
ENV    ?= qual
TAG    ?=
NS     ?= mcp-$(ENV)
RELEASE = $(SERVER)-$(ENV)

HELM_ARGS = --namespace $(NS) --values servers/$(SERVER).yaml --set env.name=$(ENV)
ifneq ($(TAG),)
HELM_ARGS += --set image.tag=$(TAG)
endif

.PHONY: template render deploy lint help

## template: render manifests (Vault <path:...> tokens left unresolved)
template:
	helm template $(RELEASE) ./chart $(HELM_ARGS)

## render: render + resolve Vault tokens with standalone AVP (no apply)
render:
	DRY_RUN=1 K8S_NAMESPACE=$(NS) deploy/deploy.sh $(SERVER) $(ENV) $(TAG)

## deploy: render + resolve Vault tokens + apply to the cluster
deploy:
	K8S_NAMESPACE=$(NS) deploy/deploy.sh $(SERVER) $(ENV) $(TAG)

## lint: helm lint the chart against a server values file
lint:
	helm lint ./chart $(HELM_ARGS)

help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'
