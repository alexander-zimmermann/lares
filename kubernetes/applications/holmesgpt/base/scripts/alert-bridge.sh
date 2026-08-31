#!/bin/sh
# Post HealthChecks that failed and were not yet sent to Alertmanager.
# These are low-urgency findings to review at leisure: severity=info routes
# them to e-mail — grouped per run, silenceable, and away from Pushover,
# which is reserved for "something is down" pages.
set -eu

NS=holmesgpt
ANN="holmes-alert-bridge/notified"

ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://prometheus-alertmanager.prometheus.svc.cluster.local:9093/api/v2/alerts}"

kubectl get healthcheck -n "$NS" -o json \
  | jq -c ".items[] | select(.status.result==\"fail\") | select((.metadata.annotations[\"$ANN\"] // \"\") != \"true\")" \
  | while IFS= read -r hc; do
      name=$(printf '%s' "$hc" | jq -r '.metadata.name')
      detail=$(printf '%s' "$hc" | jq -r '.status.rationale // "(no detail)"')
      # Holmes has no summary field; check queries lead the rationale with a one-line TL;DR.
      summary=$(printf '%s' "$detail" | head -n 1)

      # No endsAt: Alertmanager resolves the alert on its own after
      # resolve_timeout, and the email receiver sends no resolved mail.
      payload=$(jq -n --arg check "$name" --arg summary "$summary" --arg detail "$detail" \
        '[{labels: {alertname: "HolmesCheckFailed", check: $check, severity: "info", job: "holmesgpt"},
           annotations: {summary: $summary, description: $detail}}]')

      if printf '%s' "$payload" | curl -fsS -X POST -H 'Content-Type: application/json' \
           --data-binary @- "$ALERTMANAGER_URL" >/dev/null ; then
        kubectl annotate healthcheck -n "$NS" "$name" "$ANN=true" --overwrite >/dev/null
        echo "posted: $name"
      else
        echo "alertmanager post failed for $name" >&2
      fi
    done
echo "alert-bridge run complete"
