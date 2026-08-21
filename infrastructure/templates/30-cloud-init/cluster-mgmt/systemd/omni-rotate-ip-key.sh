#!/usr/bin/env bash
###############################################################################
## Omni Infra Provider Key Rotation Script
###############################################################################
## Renews infra provider key and updates the local key file
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
## Helper: Proxmox infrastructure provider compose env file
###############################################################################
write_infra_provider_env() {
  mkdir -p "$(dirname "${OMNI_IP_ENV_PATH}")"
  install -m 0600 -o "${OMNI_OWNER%%:*}" -g "${OMNI_OWNER##*:}" /dev/null "${OMNI_IP_ENV_PATH}"
  printf 'OMNI_SERVICE_ACCOUNT_KEY=%s\n' "$(< "${OMNI_IP_KEY_PATH}")" > "${OMNI_IP_ENV_PATH}"
}

###############################################################################
## Main Script
###############################################################################
## Load configuration in bash so the nested variable references resolve
# shellcheck source=/dev/null
source "${OMNI_BOOTSTRAP_CONF}" || die "Bootstrap configuration file not found at ${OMNI_BOOTSTRAP_CONF}."

## Perform key rotation
info "Rotating infra provider '${OMNI_IP_NAME}' key..."
output=$(\
  OMNI_ENDPOINT="${OMNI_API_ENDPOINT}" \
  OMNI_SERVICE_ACCOUNT_KEY="$(< "${OMNI_IP_KEY_PATH}")" \
  omnictl ip renewkey "${OMNI_IP_NAME}" \
    --ttl 720h \
    --insecure-skip-tls-verify
) || die "Failed to renew infra provider '${OMNI_IP_NAME}'."

## Extract new key from output
new_key=$(echo "${output}" | grep '^OMNI_SERVICE_ACCOUNT_KEY=' | cut -d= -f2-)

## Validate that new key was extracted
if [[ -z "${new_key}" ]]; then
    die "Failed to extract OMNI_SERVICE_ACCOUNT_KEY from omnictl output '${output}'."
fi

## Update key file and the compose env file rendered from it
echo "${new_key}" > "${OMNI_IP_KEY_PATH}"
chown "${OMNI_OWNER}" "${OMNI_IP_KEY_PATH}"
write_infra_provider_env

## Restart infra provider container with the new key
info "Restarting omni-infra-provider-proxmox with new key..."
cd "${OMNI_LOCAL_DIR}"
docker compose up -d --force-recreate omni-infra-provider-proxmox &> /dev/null || die "Failed to restart omni-infra-provider-proxmox."

success "InfraProvider '${OMNI_IP_NAME}' key renewed and updated at ${OMNI_IP_KEY_PATH}."
