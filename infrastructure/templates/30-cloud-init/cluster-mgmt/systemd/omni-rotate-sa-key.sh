#!/usr/bin/env bash
###############################################################################
## Omni Service Account Key Rotation Script
###############################################################################
## Renews service account key and updates the local key file
##
## Prerequisites:
## - omnictl installed
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

## Perform key rotation
info "Rotating service account '${OMNI_SA_NAME}' key..."
output=$(\
  OMNI_ENDPOINT="${OMNI_API_ENDPOINT}" \
  OMNI_SERVICE_ACCOUNT_KEY="$(< "${OMNI_SA_KEY_PATH}")" \
  omnictl sa renew "${OMNI_SA_NAME}" \
    --ttl 720h \
    --insecure-skip-tls-verify
) || die "Failed to renew service account '${OMNI_SA_NAME}'."

## Extract new key from output
new_key=$(echo "${output}" | grep '^OMNI_SERVICE_ACCOUNT_KEY=' | cut -d= -f2-)

## Validate that new key was extracted
if [[ -z "${new_key}" ]]; then
    die "Failed to extract OMNI_SERVICE_ACCOUNT_KEY from omnictl output '${output}'."
fi

## Update key file
echo "${new_key}" > "${OMNI_SA_KEY_PATH}"
chown "${OMNI_OWNER}" "${OMNI_SA_KEY_PATH}"
chmod 0600 "${OMNI_SA_KEY_PATH}"

success "Service account '${OMNI_SA_NAME}' key renewed and updated at ${OMNI_SA_KEY_PATH}."
