#!/usr/bin/env bash
###############################################################################
## PBS bootstrap script
###############################################################################
## Automates Proxmox Backup Server initial setup: maintenance jobs and ACME
## certs. Repositories, the subscription nag, datastores, users, tokens and
## ACLs are managed by OpenTofu (60-pbs-*). The jobs below name datastores
## that exist only after the first `tofu apply`; PBS accepts them ahead of
## the store, and they run once it is there.
##
## Prerequisites:
## - proxmox-backup-server installed.
## - Environment file in /etc/pbs/pbs-bootstrap.conf

set -euo pipefail

## Set environment file
PBS_BOOTSTRAP_CONF="/etc/pbs/pbs-bootstrap.conf"

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
## Helper: Root password
###############################################################################
set_root_password() {
  info "Setting root password..."
  echo "root:${PBS_ROOT_PASSWORD}" | chpasswd || die "Failed to set root password."

  success "Root password set."
}

###############################################################################
## Helper: Data retention setup (Pruning)
###############################################################################
setup_data_retention() {
  local datastore_name="${1}"
  local job_id="prune-${datastore_name}"
  local -a labels=("last" "hourly" "daily" "weekly" "monthly" "yearly")
  local -a values=("${@:2}")
  local -a args=()

  ## Check if prune job is already configured for datastore
  if proxmox-backup-manager prune-job list | grep -qw "${job_id}"; then
    info "Prune job ${job_id} already exists."
    return 0
  fi

  ## Build arguments for data retention policy
  for i in "${!labels[@]}"; do
    local val="${values[$i]}"
    if [[ -n "${val}" && "${val}" -gt 0 ]]; then
      args+=("--keep-${labels[$i]}" "${val}")
    fi
  done

  ## Prune job (replaces direct datastore prune settings)
  proxmox-backup-manager prune-job create "${job_id}" \
    --store "${datastore_name}" \
    --schedule "daily" \
    "${args[@]}" > /dev/null || die "Could not create prune job for ${datastore_name}."

  success "Data retention policy for ${datastore_name} set up successfully."
}

###############################################################################
## Helper: Verification job setup
###############################################################################
setup_verification() {
  local datastore_name="${1}"
  local job_id="verify-${datastore_name}"

  ## Check if verification job is already configured for datastore
  if proxmox-backup-manager verify-job list | grep -qw "${job_id}"; then
    info "Verification job ${job_id} already exists."
    return 0
  fi

  ## Verification job
  info "Setting up verification job for ${datastore_name}..."
  proxmox-backup-manager verify-job create "${job_id}" \
    --store "${datastore_name}" \
    --schedule "daily" || die "Could not create verification job for ${datastore_name}."

  success "Verification job for ${datastore_name} set up successfully."
}

###############################################################################
## Helper: Sync job setup
###############################################################################
setup_sync() {
  local job_id="pull-from-primary"

  ## Check if sync job is already configured between primary and secondary datastores
  if proxmox-backup-manager sync-job list | grep -qw "${job_id}"; then
    info "Sync job ${job_id} already exists."
    return 0
  fi

  ## Sync job from NVMe to NFS
  info "Creating sync job: Primary -> Secondary..."
  proxmox-backup-manager sync-job create "${job_id}" \
    --remote-store "${DATASTORE_PRIMARY_NAME}" \
    --store "${DATASTORE_SECONDARY_NAME}" \
    --remove-vanished true \
    --schedule "*-*-* 05:00" || die "Could not create sync job."

  success "Sync job between primary and secondary datastores set up successfully."
}

###############################################################################
## Helper: ACME account setup
###############################################################################
register_acme_account() {
  ## Check if ACME account is already registered
  if proxmox-backup-manager acme account list | grep -qw "${ACME_ACCOUNT}"; then
    info "ACME account ${ACME_ACCOUNT} already registered."
    return 0
  fi

  ## Register ACME account
  info "Registering ACME account ${ACME_ACCOUNT} (${ACME_EMAIL})..."
  printf "y\nn\n" | \
  proxmox-backup-manager acme account register "${ACME_ACCOUNT}" "${ACME_EMAIL}" \
    --directory "${ACME_DIRECTORY}"  > /dev/null || die "Failed to register ACME account."

  success "ACME account ${ACME_ACCOUNT} set up successfully."
}

###############################################################################
## Helper: ACME DNS plugin setup
###############################################################################
setup_acme_plugin() {
  local plugin_data="/tmp/acme-plugin-data"

  ## Check if ACME DNS plugin is already configured
  if proxmox-backup-manager acme plugin list | grep -qw "${ACME_DNS_PLUGIN_ID}"; then
    info "ACME plugin ${ACME_DNS_PLUGIN_ID} already configured."
    return 0
  fi

  ## Create a temporary file for the API token
  touch "${plugin_data}"
  chmod 600 "${plugin_data}"
  echo "${ACME_DNS_PLUGIN_DATA}" | tr ',' '\n' | xargs -n1 > "${plugin_data}"

  ## Register ACME plugin
  info "Registering ACME DNS plugin ${ACME_DNS_PLUGIN_ID}..."
  proxmox-backup-manager acme plugin add dns "${ACME_DNS_PLUGIN_ID}" \
    --api "${ACME_DNS_ID}" \
    --data "${plugin_data}" || die "Failed to register ACME DNS plugin."

  ## Remove temporary file
  rm -f "${plugin_data}"

  success "ACME DNS plugin ${ACME_DNS_PLUGIN_ID} registered successfully."
}

###############################################################################
## Helper: ACME certificate issue
###############################################################################
setup_issue_certificate() {
  ## Build Bash array from the domain list
  readarray -t acme_domains <<< "$(echo "${ACME_DOMAINS}" | tr ',' '\n' | xargs -n1)"

  ## Construct domain flags for certificate issuing
  local -a domain_flags=()
  for i in "${!acme_domains[@]}"; do
    domain_flags+=("--acmedomain${i}" "domain=${acme_domains[$i]},plugin=${ACME_DNS_PLUGIN_ID}")
  done

  ## Apply ACME account and domains
  info "Applying ACME account and domains to PBS node..."
  proxmox-backup-manager node update \
    --acme "account=${ACME_ACCOUNT}" \
    "${domain_flags[@]}" || die "Failed to set ACME node configuration."

  ## Skip renewal if a valid ACME certificate exists (not self-signed, >30 days remaining)
  if [[ -f /etc/proxmox-backup/proxy.pem ]] \
    && ! openssl x509 -noout -issuer -in /etc/proxmox-backup/proxy.pem 2>/dev/null | grep -q "O=Proxmox Backup Server" \
    && openssl x509 -checkend 2592000 -noout -in /etc/proxmox-backup/proxy.pem 2>/dev/null; then
    info "Valid ACME certificate exists. Skipping renewal."
    return 0
  fi

  info "Ordering ACME certificate (this may take a few minutes)..."
  proxmox-backup-manager acme cert order \
    --force || die "Failed to generate certificates for ${ACME_DOMAINS}."

  success "ACME configuration complete."
}

###############################################################################
## Main Script
###############################################################################
info "===================================="
info " Proxmox Backup Server Bootstrap "
info "===================================="

## Load environment files
# shellcheck source=/dev/null
source "${PBS_BOOTSTRAP_CONF}" || die "Bootstrap configuration file not found at ${PBS_BOOTSTRAP_CONF}."

## Root password (the 60-pbs provider authenticates with it)
set_root_password

## Setup data retention
info "Setting up data retention for datastores..."
setup_data_retention "${DATASTORE_PRIMARY_NAME}" \
  "${PRIMARY_KEEP_LAST}" "0" "${PRIMARY_KEEP_DAILY}" "${PRIMARY_KEEP_WEEKLY}" \
  "${PRIMARY_KEEP_MONTHLY}" "${PRIMARY_KEEP_YEARLY}"
setup_data_retention "${DATASTORE_SECONDARY_NAME}" \
  "${SECONDARY_KEEP_LAST}" "${SECONDARY_KEEP_HOURLY}" "${SECONDARY_KEEP_DAILY}" \
  "${SECONDARY_KEEP_WEEKLY}" "${SECONDARY_KEEP_MONTHLY}" "${SECONDARY_KEEP_YEARLY}"

## Setup Verification
info "Setting up verification for Primary datastores..."
setup_verification "${DATASTORE_PRIMARY_NAME}"
setup_verification "${DATASTORE_SECONDARY_NAME}"

## Setup Sync Job
info "Setting up Sync Job (Primary -> Secondary)..."
setup_sync

## Setup ACME
info "Setting up ACME..."
register_acme_account
setup_acme_plugin
setup_issue_certificate

success "===================================="
success " PBS Bootstrap complete!"
success "===================================="
