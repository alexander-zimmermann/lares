#!/bin/sh
set -eu

# Required environment variables:
#   NAMESPACE        - crowdsec namespace
#   SELECTOR         - label selector for the LAPI pod
#   WATCHER_NAME     - watcher machine to register
#   WATCHER_PASSWORD - LAPI password for that watcher

attempt=0

while [ "$attempt" -lt 60 ]; do
  LAPI_POD=$(kubectl -n "$NAMESPACE" get pod -l "$SELECTOR" \
    -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' \
    | awk '{print $1}') || LAPI_POD=""

  # --force rewrites the password, so re-runs converge on the sealed secret.
  if [ -n "$LAPI_POD" ] && kubectl -n "$NAMESPACE" exec "$LAPI_POD" -- \
      cscli machines add "$WATCHER_NAME" --password "$WATCHER_PASSWORD" -f /dev/null --force; then
    echo "watcher $WATCHER_NAME registered via $LAPI_POD"
    exit 0
  fi

  attempt=$((attempt + 1))
  sleep 5
done

echo "lapi did not become reachable"
exit 1
