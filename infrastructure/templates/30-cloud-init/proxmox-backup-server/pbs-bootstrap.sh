#!/usr/bin/env bash
###############################################################################
## PBS bootstrap script
###############################################################################
## Automates Proxmox Backup Server initial setup, including datastore
## configuration, user initialization, maintenance jobs, and ACME certs.
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
## Helper: System configuration
###############################################################################
setup_system_config() {
  local enterprise_source="/etc/apt/sources.list.d/pbs-enterprise.sources"

  ## Set root password
  info "Setting root password..."
  echo "root:${PBS_ROOT_PASSWORD}" | chpasswd || die "Failed to set root password."

  ## Disable enterprise repo
  info "Disabling enterprise repository..."
  sed -i 's/^Enabled:.*/Enabled: false/' "${enterprise_source}"

  success "System configuration set up successfully."
}

###############################################################################
## Helper: Disable subscription nag
###############################################################################
disable_subscription_nag() {
  local nag_script="/etc/apt/apt.conf.d/no-nag-script"

  if [[ -f "${nag_script}" ]]; then
    info "Subscription nag already disabled."
    return 0
  fi

  info "Disabling subscription nag..."
  ## APT hook: patches proxmoxlib.js after every package install/upgrade
  local hook
  hook='DPkg::Post-Invoke {'
  hook+=' "if [ -s /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]'
  hook+=' && ! grep -q -F '"'"'NoMoreNagging'"'"''
  hook+='     /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js;'
  hook+=' then sed -i '"'"'/data\.status/{s/\!//;s/active/NoMoreNagging/}'"'"''
  hook+='     /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js;'
  hook+=' fi" };'
  echo "${hook}" > "${nag_script}"

  ## Reinstall to immediately trigger the hook
  apt-get --reinstall install proxmox-widget-toolkit -y > /dev/null \
    || die "Failed to reinstall proxmox-widget-toolkit."

  success "Subscription nag disabled."
}

###############################################################################
## Helper: User setup
###############################################################################
create_user() {
  local user="${1}@pbs"
  local password="${2}"

  ### Check if user already exists
  if proxmox-backup-manager user list | grep -qw "${user}"; then
    info "User ${user} already exists."
    return 0
  fi

  ## Creating user
  info "Creating user ${user}..."
  proxmox-backup-manager user create "${user}" \
    --password "${password}" || die "Failed to create user ${user}."

  success "User ${user} created."
}

###############################################################################
## Helper: API token setup
###############################################################################
create_api_token() {
  local user="${1}@pbs"
  local token_name="${2}"

  ## Check if token already exists
  if proxmox-backup-manager user list-tokens "${user}" | grep -qw "${token_name}"; then
    info "API token ${user}!${token_name} already exists."
    return 0
  fi

  ## Create API token and capture secret
  info "Creating API token ${user}!${token_name}..."
  local token_output
  token_output=$(proxmox-backup-manager user generate-token "${user}" "${token_name}") \
    || die "Failed to create API token for ${user}."

  ## Extract and store token secret for external consumption
  local token_secret
  token_secret=$(echo "${token_output}" | grep -oP '"value":\s*"\K[^"]*')
  echo "${token_secret}" > "/etc/pbs/api-token-${1}-${token_name}.secret"
  chmod 600 "/etc/pbs/api-token-${1}-${token_name}.secret"

  success "API token ${user}!${token_name} created. Secret stored in /etc/pbs/api-token-${1}-${token_name}.secret"
}

###############################################################################
## Helper: ACL setup
###############################################################################
setup_acl() {
  local user="${1}@pbs"
  local role="${2}"
  local path="${3}"
  local token_name="${4:-}"

  ## Build auth-id: user@pbs or user@pbs!token
  local auth_id="${user}"
  if [[ -n "${token_name}" ]]; then
    auth_id="${user}!${token_name}"
  fi

  ## Check if ACL is already set
  if proxmox-backup-manager acl list | grep -w "${auth_id}" | grep -qw "${role}"; then
    info "ACL ${role} for ${auth_id} on ${path} already set."
    return 0
  fi

  info "Assigning ${role} role to ${auth_id} on ${path}..."
  proxmox-backup-manager acl update "${path}" "${role}" \
    --auth-id "${auth_id}" || die "Failed to assign role to ${auth_id}."

  success "Assigned ${role} role to ${auth_id} on ${path}."
}

###############################################################################
## Helper: Datastore setup
###############################################################################
setup_datastore() {
  local datastore_name="${1}"
  local datastore_path="${2}"

  ## Check if datastore is already configured in PBS
  if proxmox-backup-manager datastore list | grep -qw "${datastore_name}"; then
    info "Datastore ${datastore_name} already exists in PBS configuration."
    return 0
  fi

  ## Create datastore
  info "Initializing datastore ${datastore_name} at ${datastore_path}..."
  proxmox-backup-manager datastore create \
    "${datastore_name}" "${datastore_path}" \
    > /dev/null || die "Failed to create datastore ${datastore_name}."

  success "Datastore ${datastore_name} created successfully."
}

###############################################################################
## Helper: NFS-backed datastore setup (with all_squash remapping - Unifi UNAS)
###############################################################################
## NFS with all_squash remaps UID/GID and the server may alter permissions,
## so PBS cannot create .chunks directly on NFS. This function handles:
##   1. Datastore already registered in PBS — skip.
##   2. Unmount NFS, let PBS create the datastore locally (correct perms).
##   3. If the NFS has no existing data, seed it with the local .chunks/.lock.
##   4. Remove local metadata and remount NFS.
setup_nfs_datastore() {
  local datastore_name="${1}"
  local datastore_path="${2}"
  local temp_dir=$(mktemp -d)

  ## Already registered in PBS — nothing to do
  if proxmox-backup-manager datastore list | grep -qw "${datastore_name}"; then
    info "Datastore ${datastore_name} already exists in PBS configuration."
    return 0
  fi

  ## Unmount NFS so PBS can create the datastore on the local filesystem
  info "Unmounting NFS at ${datastore_path} for local datastore creation..."
  umount "${datastore_path}" || die "Failed to unmount ${datastore_path}."

  ## Create datastore locally (PBS sets correct permissions and ownership)
  info "Creating datastore ${datastore_name} locally..."
  proxmox-backup-manager datastore create \
    "${datastore_name}" "${datastore_path}" \
    > /dev/null || die "Failed to create datastore ${datastore_name}."

  ## Preserve local metadata before remounting
  mv "${datastore_path}/.chunks" "${temp_dir}/"
  mv "${datastore_path}/.lock" "${temp_dir}/"

  mount "${datastore_path}" || die "Failed to remount NFS at ${datastore_path}."

  ## Seed NFS with local metadata if no existing data
  if [[ ! -d "${datastore_path}/.chunks" ]]; then
    info "Fresh NFS detected. Seeding with datastore metadata..."
    cp -a --no-preserve=ownership "${temp_dir}/.chunks" "${datastore_path}/"
    cp -a --no-preserve=ownership "${temp_dir}/.lock" "${datastore_path}/"
  else
    info "Existing datastore data found on NFS."
  fi

  ## Clean up local temp
  rm -rf "${temp_dir}"

  success "Datastore ${datastore_name} set up on NFS successfully."
}

###############################################################################
## Helper: Data retention setup (GC & Pruning)
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

  ## Garbage collection job (still part of datastore configuration)
  info "Update garbage collection job for ${datastore_name}..."
  proxmox-backup-manager datastore update "${datastore_name}" \
    --gc-schedule "daily" || die "Could not update garbage collection schedule for ${datastore_name}."

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
    --schedule "Sat 04:00" || die "Could not create verification job for ${datastore_name}."

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

  ## Sync job form NVMe to NFS
  info "Creating sync job: Primary -> Secondary..."
  proxmox-backup-manager sync-job create "${job_id}" \
    --remote-store "${DATASTORE_PRIMARY_NAME}" \
    --store "${DATASTORE_SECONDARY_NAME}" \
    --schedule "*-*-* 05:00" || die "Could not create sync job."

  success "Sync job for between primary and secondary datastores set up successfully."
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
source "${PBS_BOOTSTRAP_CONF}" || die "Bootstrap configuration file not found at ${PBS_BOOTSTRAP_CONF}."

## System configuration
info "Configuring system settings..."
setup_system_config

## Disable subscription nag
info "Disabling subscription nag..."
disable_subscription_nag

## Initialize datastores
info "Setting up datastores..."
setup_datastore "${DATASTORE_PRIMARY_NAME}" "${DATASTORE_PRIMARY_PATH}"
setup_nfs_datastore "${DATASTORE_SECONDARY_NAME}" "${DATASTORE_SECONDARY_PATH}"

## Create initial user
info "Setting up initial user..."
create_user "${PBS_INITIAL_USERNAME}" "${PBS_INITIAL_PASSWORD}"
setup_acl "${PBS_INITIAL_USERNAME}" "Admin" "/"

## Create backup user
info "Setting up backup user..."
create_user "${PBS_BACKUP_USERNAME}" "${PBS_BACKUP_PASSWORD}"
setup_acl "${PBS_BACKUP_USERNAME}" "DatastoreAdmin" "/datastore/${DATASTORE_PRIMARY_NAME}"

## Create homepage user (read-only monitoring via API token)
info "Setting up homepage user..."
create_user "${PBS_HOMEPAGE_USERNAME}" "${PBS_HOMEPAGE_PASSWORD}"
setup_acl "${PBS_HOMEPAGE_USERNAME}" "Audit" "/"
create_api_token "${PBS_HOMEPAGE_USERNAME}" "homepage"
setup_acl "${PBS_HOMEPAGE_USERNAME}" "Audit" "/" "homepage"

## Create metrics user (read-only Prometheus scraping via API token)
info "Setting up metrics user..."
create_user "${PBS_METRICS_USERNAME}" "${PBS_METRICS_PASSWORD}"
setup_acl "${PBS_METRICS_USERNAME}" "Audit" "/"
create_api_token "${PBS_METRICS_USERNAME}" "metrics"
setup_acl "${PBS_METRICS_USERNAME}" "Audit" "/" "metrics"

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
