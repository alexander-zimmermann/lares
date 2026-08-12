#!/bin/sh
set -eu

# Required environment variables:
#   NAMESPACE       - crowdsec namespace
#   SELECTOR        - label selector for the LAPI pod
#   MACHINE_PATTERN - machines eligible for pruning; log processors register under their pod name

LAPI_POD=$(kubectl -n "$NAMESPACE" get pod -l "$SELECTOR" \
  -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' \
  | awk '{print $1}')

if [ -z "$LAPI_POD" ]; then
  echo "no running lapi pod found"
  exit 1
fi

kubectl -n "$NAMESPACE" get pods --no-headers -o custom-columns=":metadata.name" >/tmp/pods

kubectl -n "$NAMESPACE" exec "$LAPI_POD" -- cscli machines list -o raw \
  | awk -F, 'NR > 1 { print $1 }' >/tmp/machines

pruned=0

while read -r machine; do
  [ -n "$machine" ] || continue

  # Everything else is a watcher (homepage widget), which never sends a heartbeat.
  if ! echo "$machine" | grep -qE "$MACHINE_PATTERN"; then
    continue
  fi

  if grep -qxF "$machine" /tmp/pods; then
    continue
  fi

  echo "pruning $machine: pod is gone"
  kubectl -n "$NAMESPACE" exec "$LAPI_POD" -- cscli machines delete "$machine"
  pruned=$((pruned + 1))
done </tmp/machines

echo "pruned $pruned stale machine(s)"
