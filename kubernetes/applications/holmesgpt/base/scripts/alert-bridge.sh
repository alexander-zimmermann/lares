#!/bin/sh
# Notify Pushover about HealthChecks that failed and were not yet sent.
# Mirrors the ArgoCD notifications pattern: POST a JSON payload to the Pushover API.
set -eu

NS=holmesgpt
ANN="holmes-alert-bridge/notified"

kubectl get healthcheck -n "$NS" -o json \
  | jq -c ".items[] | select(.status.result==\"fail\") | select((.metadata.annotations[\"$ANN\"] // \"\") != \"true\")" \
  | while IFS= read -r hc; do
      name=$(printf '%s' "$hc" | jq -r '.metadata.name')
      msg=$(printf '%s' "$hc" | jq -r '.status.rationale // .status.message // "no detail"' | head -c 1000)
      body=$(jq -n --arg t "$PUSHOVER_TOKEN" --arg u "$PUSHOVER_USER" \
                   --arg ti "HolmesGPT check failed: $name" --arg m "$msg" \
             '{token:$t, user:$u, title:$ti, message:$m, priority:1, sound:"siren"}')
      code=$(curl -s -o /dev/null -w '%{http_code}' -H "Content-Type: application/json" \
             -d "$body" https://api.pushover.net/1/messages.json)
      if [ "$code" = "200" ]; then
        kubectl annotate healthcheck -n "$NS" "$name" "$ANN=true" --overwrite >/dev/null
        echo "notified: $name"
      else
        echo "pushover POST failed ($code) for $name" >&2
      fi
    done
echo "alert-bridge run complete"
