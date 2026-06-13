#!/bin/sh
# POSIX sh (busybox ash in alpine/k8s); no pipefail — failed curls are caught by
# the explicit empty/null checks on the values extracted from each response.
set -eu

# Provisions ArgoCD account tokens from a YAML config file.
#
# Required environment variables:
#   ARGOCD_URL    - e.g. http://argocd-server.gitops-controller.svc.cluster.local
#   ADMIN_USER    - ArgoCD admin username
#   ADMIN_PASS    - ArgoCD admin password
#
# Config file at /config/service-accounts.yaml defines accounts to provision.

CONFIG="/config/service-accounts.yaml"
COUNT=$(yq '.service_accounts | length' "$CONFIG")

if [ "$COUNT" -eq 0 ]; then
  echo "No service accounts defined in config, nothing to do."
  exit 0
fi

# Login to ArgoCD and get session token
echo "Authenticating with ArgoCD..."
SESSION_TOKEN=$(curl -sf -X POST "$ARGOCD_URL/api/v1/session" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}" \
  | jq -r '.token')

if [ -z "$SESSION_TOKEN" ] || [ "$SESSION_TOKEN" = "null" ]; then
  echo "ERROR: Failed to authenticate with ArgoCD"
  exit 1
fi

i=0
while [ "$i" -lt "$COUNT" ]; do
  ACCOUNT=$(yq ".service_accounts[$i].account" "$CONFIG")
  SECRET_NAME=$(yq ".service_accounts[$i].secret_name" "$CONFIG")
  SECRET_NS=$(yq ".service_accounts[$i].secret_namespace" "$CONFIG")

  echo "--- Processing account: $ACCOUNT ---"

  # Skip if secret already exists
  if kubectl get secret "$SECRET_NAME" -n "$SECRET_NS" >/dev/null 2>&1; then
    echo "Secret $SECRET_NAME already exists, skipping"
    i=$((i + 1))
    continue
  fi

  # Generate API token for the account
  echo "Generating token for account '$ACCOUNT'..."
  TOKEN=$(curl -sf -X POST \
    -H "Authorization: Bearer $SESSION_TOKEN" \
    -H "Content-Type: application/json" \
    "$ARGOCD_URL/api/v1/account/$ACCOUNT/token" \
    | jq -r '.token')

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "ERROR: Failed to generate token for account '$ACCOUNT'"
    i=$((i + 1))
    continue
  fi

  # Store as Kubernetes Secret
  kubectl create secret generic "$SECRET_NAME" \
    -n "$SECRET_NS" \
    --from-literal=token="$TOKEN"

  echo "Done: secret $SECRET_NAME created in $SECRET_NS"
  i=$((i + 1))
done

echo "All accounts processed."
