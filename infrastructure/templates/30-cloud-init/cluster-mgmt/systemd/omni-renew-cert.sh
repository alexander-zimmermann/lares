#!/usr/bin/env bash
###############################################################################
## Omni SSL Renewal Script
###############################################################################
## Runs lego renew with a hook to reload Omni
##
## Prerequisites:
## - lego installed
## - Configuration file in /etc/omni/omni-bootstrap.conf

set -euo pipefail

## Set configuration file
OMNI_BOOTSTRAP_CONF="/etc/omni/omni-bootstrap.conf"

###############################################################################
## Helper: Logging functions
###############################################################################
info() {
  printf "[INFO]  %s\n" "${1}"
}

success() {
  printf "[SUCCESS] %s\n" "${1}"
}

die() {
  printf "[ERROR] %s\n" "${1}"
  exit 1
}

###############################################################################
## Main Script
###############################################################################
## Load configuration in bash so the nested variable references resolve
# shellcheck source=/dev/null
source "${OMNI_BOOTSTRAP_CONF}" || die "Bootstrap configuration file not found at ${OMNI_BOOTSTRAP_CONF}."

## Construct domain flags for running lego (xargs trims whitespace around commas)
info "Configuring domains..."
domain_flags=("--domains=${ACME_PRIMARY_DOMAIN}")
readarray -t domains_arr <<< "$(echo "${ACME_SAN_DOMAINS:-}" | tr ',' '\n' | xargs -n1)"
for domain in "${domains_arr[@]}"; do
  if [[ -n "${domain}" ]]; then
    domain_flags+=("--domains=${domain}")
  fi
done

## Run lego (v5 merged renew into run: renews only when due, ARI/lifetime-based)
info "Checking for SSL renewal..."
before_mtime=$(stat -c %Y "${LEGO_CERT_DIR}/${ACME_PRIMARY_DOMAIN}.crt" 2>/dev/null || echo 0)
## Fixed propagation wait: outbound :53 is blocked and split-DNS hides the TXT record from the local resolver
CLOUDFLARE_DNS_API_TOKEN="${ACME_CF_TOKEN}" \
CLOUDFLARE_EMAIL="${ACME_EMAIL}" \
lego run \
  --email="${ACME_EMAIL}" \
  --dns="cloudflare" \
  --dns.propagation.wait 30s \
  --accept-tos \
  "${domain_flags[@]}" || die "Failed to renew SSL certificate for ${ACME_PRIMARY_DOMAIN}."

## Deploy to Omni only when the certificate actually changed
after_mtime=$(stat -c %Y "${LEGO_CERT_DIR}/${ACME_PRIMARY_DOMAIN}.crt" 2>/dev/null || echo 0)
if [[ "${after_mtime}" != "${before_mtime}" ]]; then
  info "Certificate renewed. Deploying to Omni..."
  cp "${LEGO_CERT_DIR}/"* "${OMNI_CERT_DIR}"
  chown -R "${OMNI_OWNER}" "${OMNI_CERT_DIR}"
  docker restart omni
fi

success "SSL renewal check completed."
