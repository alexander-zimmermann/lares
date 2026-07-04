#!/bin/sh
# Notify by e-mail about HealthChecks that failed and were not yet sent.
# These are low-urgency (Sev 3/4) findings to review at leisure, so they go to
# e-mail via the cluster-internal smtprelay — no length limit, easy to copy —
# rather than Pushover, which is reserved for "something is down" pages.
set -eu

NS=holmesgpt
ANN="holmes-alert-bridge/notified"

SMTP_HOST="${SMTP_HOST:-smtprelay.smtprelay.svc.cluster.local}"
SMTP_PORT="${SMTP_PORT:-25}"
MAIL_FROM="${MAIL_FROM:-admin@zimmermann.sh}"
MAIL_TO="${MAIL_TO:-admin@zimmermann.sh}"

kubectl get healthcheck -n "$NS" -o json \
  | jq -c ".items[] | select(.status.result==\"fail\") | select((.metadata.annotations[\"$ANN\"] // \"\") != \"true\")" \
  | while IFS= read -r hc; do
      name=$(printf '%s' "$hc" | jq -r '.metadata.name')
      result=$(printf '%s' "$hc" | jq -r '.status.result // "fail"')
      detail=$(printf '%s' "$hc" | jq -r '.status.rationale // "(no detail)"')
      # Holmes has no summary field; check queries lead the rationale with a one-line TL;DR.
      summary=$(printf '%s' "$detail" | head -n 1)
      started=$(printf '%s' "$hc" | jq -r '.status.startTime // "-"')
      date=$(date -u +'%a, %d %b %Y %H:%M:%S +0000')

      # Full rationale, no truncation — e-mail has no practical length limit.
      mail=$(printf 'From: HolmesGPT <%s>\nTo: %s\nSubject: [HolmesGPT] check failed: %s\nDate: %s\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n\nResult:  %s\nCheck:   %s\nStarted: %s\n\nSummary\n-------\n%s\n\nFull rationale\n--------------\n%s\n' \
             "$MAIL_FROM" "$MAIL_TO" "$name" "$date" \
             "$result" "$name" "$started" "$summary" "$detail")

      if printf '%s' "$mail" | curl -sS --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
           --mail-from "$MAIL_FROM" --mail-rcpt "$MAIL_TO" --upload-file - ; then
        kubectl annotate healthcheck -n "$NS" "$name" "$ANN=true" --overwrite >/dev/null
        echo "emailed: $name"
      else
        echo "smtp send failed for $name" >&2
      fi
    done
echo "alert-bridge run complete"
