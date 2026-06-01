#!/usr/bin/env bash
# =============================================================================
# Non-GitOps deploy: render the chart for one server+env, resolve the Vault
# <path:...> tokens with the STANDALONE Argo CD Vault Plugin, and apply.
#
# This is the same pipeline Argo CD runs internally:
#
#   helm template ... | argocd-vault-plugin generate - | oc apply -f -
#
# but driven from your CI (GitLab) instead of an Argo CD sync. Your preferred
# secret syntax keeps working unchanged:
#
#   <path:secret/data/mcp/{{namespace}}/example-server#openai_api_key>
#
# -----------------------------------------------------------------------------
# Requirements on the runner:
#   - helm
#   - argocd-vault-plugin  (https://argocd-vault-plugin.readthedocs.io)
#   - oc (or kubectl) with a context/token for the target cluster
#
# Vault auth for argocd-vault-plugin (set as CI variables), e.g. AppRole:
#   AVP_TYPE=vault
#   VAULT_ADDR=https://vault.example.com
#   AVP_AUTH_TYPE=approle
#   AVP_ROLE_ID / AVP_SECRET_ID
# ...or a token: AVP_AUTH_TYPE=token + VAULT_TOKEN. See AVP docs for k8s auth.
# -----------------------------------------------------------------------------
# Usage:
#   deploy/deploy.sh <server> <env> [image-tag]
#
# Examples:
#   deploy/deploy.sh example-server qual
#   deploy/deploy.sh example-server qual "$CI_COMMIT_SHORT_SHA"
#
# Env overrides:
#   K8S_NAMESPACE   target namespace      (default: mcp-<env>)
#   APPLY_CMD       apply command          (default: oc apply -f -)
#   DRY_RUN=1       render only, print to stdout, do not apply
#   KUBECTL=kubectl use kubectl instead of oc for the default APPLY_CMD
# =============================================================================
set -euo pipefail

SERVER="${1:?usage: deploy.sh <server> <env> [image-tag]}"
ENV="${2:?usage: deploy.sh <server> <env> [image-tag]}"
IMAGE_TAG="${3:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="$REPO_ROOT/chart"
VALUES_FILE="$REPO_ROOT/servers/${SERVER}.yaml"

[[ -f "$VALUES_FILE" ]] || { echo "no such server file: $VALUES_FILE" >&2; exit 1; }

K8S_NAMESPACE="${K8S_NAMESPACE:-mcp-${ENV}}"
RELEASE="${SERVER}-${ENV}"
KUBECTL="${KUBECTL:-oc}"
APPLY_CMD="${APPLY_CMD:-$KUBECTL apply -f -}"

# --- 1. Render the chart for this server+env --------------------------------
helm_args=(
  template "$RELEASE" "$CHART_DIR"
  --namespace "$K8S_NAMESPACE"
  --values "$VALUES_FILE"
  --set "env.name=${ENV}"
)
# {{namespace}} defaults to env.name; uncomment to decouple the Vault segment:
# helm_args+=(--set "env.namespace=${ENV}")
[[ -n "$IMAGE_TAG" ]] && helm_args+=(--set "image.tag=${IMAGE_TAG}")

echo ">> helm template $RELEASE (env=$ENV, ns=$K8S_NAMESPACE, tag=${IMAGE_TAG:-<from values>})" >&2

# --- 2. Resolve <path:...> tokens against Vault, then apply -----------------
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  helm "${helm_args[@]}" | argocd-vault-plugin generate -
else
  helm "${helm_args[@]}" | argocd-vault-plugin generate - | $APPLY_CMD
  echo ">> applied $RELEASE to namespace $K8S_NAMESPACE" >&2
fi
