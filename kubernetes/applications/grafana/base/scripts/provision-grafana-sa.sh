#!/bin/sh
# POSIX sh (busybox ash in alpine/k8s); no pipefail — failed curls are caught by
# the explicit empty/null checks on the values extracted from each response.
set -eu

# Provisions Grafana service accounts from a YAML config file.
#
# Required environment variables:
#   GRAFANA_URL   - e.g. http://grafana.grafana.svc.cluster.local
#   ADMIN_USER    - Grafana admin username
#   ADMIN_PASS    - Grafana admin password
#
# Config file at /config/service-accounts.yaml defines service accounts to create.

CONFIG="/config/service-accounts.yaml"
COUNT=$(yq '.service_accounts | length' "$CONFIG")

if [ "$COUNT" -eq 0 ]; then
  echo "No service accounts defined in config, nothing to do."
  exit 0
fi

i=0
while [ "$i" -lt "$COUNT" ]; do
  SA_NAME=$(yq ".service_accounts[$i].name" "$CONFIG")
  SA_ROLE=$(yq ".service_accounts[$i].role" "$CONFIG")
  TOKEN_NAME=$(yq ".service_accounts[$i].token_name" "$CONFIG")
  SECRET_NAME=$(yq ".service_accounts[$i].secret_name" "$CONFIG")
  SECRET_NS=$(yq ".service_accounts[$i].secret_namespace" "$CONFIG")

  echo "--- Processing service account: $SA_NAME ---"

  # Skip if secret already exists
  if kubectl get secret "$SECRET_NAME" -n "$SECRET_NS" >/dev/null 2>&1; then
    echo "Secret $SECRET_NAME already exists, skipping"
    i=$((i + 1))
    continue
  fi

  # Get existing SA or create it
  SA_ID=$(curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
    "$GRAFANA_URL/api/serviceaccounts/search?query=$SA_NAME" \
    | jq -r --arg name "$SA_NAME" '.serviceAccounts[] | select(.name == $name) | .id' | head -1)

  if [ -z "$SA_ID" ]; then
    echo "Creating Grafana Service Account '$SA_NAME'..."
    SA_ID=$(curl -sf -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
      -H "Content-Type: application/json" \
      "$GRAFANA_URL/api/serviceaccounts" \
      -d "{\"name\":\"$SA_NAME\",\"role\":\"$SA_ROLE\"}" | jq -r '.id')
  fi
  echo "SA ID: $SA_ID"

  # Create token
  TOKEN=$(curl -sf -X POST -u "$ADMIN_USER:$ADMIN_PASS" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/serviceaccounts/$SA_ID/tokens" \
    -d "{\"name\":\"$TOKEN_NAME\"}" | jq -r '.key')

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "ERROR: Failed to create token for service account '$SA_NAME'"
    exit 1
  fi

  # Store as Kubernetes Secret
  kubectl create secret generic "$SECRET_NAME" \
    -n "$SECRET_NS" \
    --from-literal=token="$TOKEN"

  echo "Done: secret $SECRET_NAME created in $SECRET_NS"
  i=$((i + 1))
done

echo "All service accounts processed."
