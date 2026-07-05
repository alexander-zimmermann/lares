#!/usr/bin/env bash
###############################################################################
## Omni bootstrap script
###############################################################################
## Automates Omni setup, including Repo Clone, Certificates, GPG, and Data persistence.
##
## Prerequisites:
## - git, lego, gpg installed.
## - Environment files in /opt/omni/.env/{bootstrap,docker,lego}

set -euo pipefail

## Set environment file
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
## Helper: Download curl for internal healthchecks
###############################################################################
download_static_curl() {
  local curl_version=""

  ## Check if static curl exists locally (either from backup extraction or previous run)
  if [[ -x ${CURL_PATH} ]]; then
    curl_version=$("${CURL_PATH}" -V | head -n1 | awk '{print $2}')
  fi

  ## Check version using binary introspection
  if [[ -x ${CURL_PATH} && ${curl_version} == "${CURL_VERSION}" ]]; then
    info "Static curl (${CURL_VERSION}) already exists. Skipping download."
    return 0
  fi

  ## Downloading static curl (--fail so an HTTP error page is not saved as the binary)
  info "Downloading static curl for internal healthchecks..."
  curl -fL -s -o "/tmp/${CURL_TAR}" "${CURL_URL}" || die "Failed to download static curl."

  ## Extracting static curl
  info "Extracting static curl..."
  mkdir -p "/tmp/curl-extract"
  tar -xJf "/tmp/${CURL_TAR}" -C "/tmp/curl-extract"
  cp "/tmp/curl-extract/curl" "${CURL_PATH}"
  chmod +x "${CURL_PATH}"

  ## Cleanup
  rm -rf "/tmp/${CURL_TAR}" "/tmp/curl-extract"

  success "Static curl installed successfully at ${CURL_PATH}."
}

###############################################################################
## Helper: Download omnictl for infrastructure provider key generation
###############################################################################
download_omnictl() {
  local omnictl_version=""

  ## Check if omnictl exists locally (either from backup extraction or previous run)
  if [[ -x ${OMNICTL_PATH} ]]; then
    omnictl_version=$("${OMNICTL_PATH}" -v | awk '{print $3}')
  fi

  ## Check version using binary introspection
  if [[ -x ${OMNICTL_PATH} && ${omnictl_version} == "${OMNICTL_VERSION}" ]]; then
    info "Omnictl (${OMNICTL_VERSION}) already exists. Skipping download."
    return 0
  fi

  ## Downloading omnictl (--fail so an HTTP error page is not saved as the binary)
  info "Installing omnictl (version ${OMNICTL_VERSION})..."
  curl -fL -s -o "${OMNICTL_PATH}" "${OMNICTL_URL}" || die "Failed to download omnictl."
  chmod +x "${OMNICTL_PATH}"

  success "omnictl installed successfully at ${OMNICTL_PATH}."
}

###############################################################################
## Helper: SSL certificates generation
###############################################################################
setup_certificates() {
  mkdir -p "${OMNI_CERT_DIR}"

  ## Reuse local certificates only if still valid for at least 30 more days
  if [[ -f "${OMNI_TLS_CERT_PATH}" ]] && openssl x509 -checkend 2592000 -noout -in "${OMNI_TLS_CERT_PATH}" &> /dev/null; then
    info "Valid certificates found in local cert directory. Skipping generation."
    return 0
  fi

  ## Build Bash array from the domain list
  readarray -t acme_domains <<< "$(echo "${ACME_DOMAINS}" | tr ',' '\n' | xargs -n1)"

  ## Construct domain flags for certificate issuing
  local -a domain_flags=()
  for domain in "${acme_domains[@]}"; do
    domain_flags+=("--domains=${domain}")
  done

  ## Running lego to generate certificates (v5 CLI: flags are subcommand options)
  info "No valid certificates found. Generating new certificates via Let's Encrypt..."
  ## Fixed propagation wait: outbound :53 is blocked and split-DNS hides the TXT record from the local resolver
  CLOUDFLARE_DNS_API_TOKEN="${ACME_CF_TOKEN}" \
  CLOUDFLARE_EMAIL="${ACME_EMAIL}" \
  lego run \
    --email="${ACME_EMAIL}" \
    --dns="cloudflare" \
    --dns.propagation.wait 30s \
    --accept-tos \
    "${domain_flags[@]}" || die "Failed to generate certificates for ${ACME_DOMAINS}."

  ## Copy certificates into local cert directory
  info "Copying new certificates to ${OMNI_CERT_DIR}..."
  cp "${LEGO_CERT_DIR}/"* "${OMNI_CERT_DIR}"

  success "Certificates set up successfully."
}

###############################################################################
## Helper: GPG keys generation
###############################################################################
setup_gpg() {
  mkdir -p "${OMNI_KEY_DIR}"

  ## Check if GPG key exists locally (either from backup extraction or previous run)
  if [[ -f "${OMNI_PRIVATE_KEY_PATH}" ]]; then
    info "GPG key found in local key directory. Skipping generation."
    return 0
  fi

  ## Generating GPG key
  info "GPG key not found. Generating new primary GPG key (RSA 4096)..."
  gpg \
    --batch \
    --quiet \
    --passphrase '' \
    --pinentry-mode loopback \
    --quick-generate-key "Omni (Used for etcd data encryption) <${OMNI_PRIVATE_KEY_EMAIL}>" \
    rsa4096 \
    cert \
    never || die "Failed to generate primary key."
  info "Primary key generated successfully"

  ## Get key fingerprint
  info "Retrieving GPG key fingerprint..."
  local list_keys key_fingerprint
  list_keys=$(gpg --quiet --list-secret-keys --with-colons "${OMNI_PRIVATE_KEY_EMAIL}")
  key_fingerprint=$(echo "${list_keys}" | grep '^fpr:' | head -n1 | cut -d: -f10)
  info "GPG key fingerprint: ${key_fingerprint}"

  ## Add encryption subkey
  info "Adding encryption subkey..."
  gpg \
    --batch \
    --quiet \
    --passphrase '' \
    --pinentry-mode loopback \
    --quick-add-key "${key_fingerprint}" \
    rsa4096 \
    encr \
    never || die "Failed to add encryption subkey."
  info "Encryption subkey added successfully!"

  ## Verifying GPG key configuration
  info "Verifying GPG key configuration..."
  gpg \
    --quiet \
    --list-secret-keys \
    --with-subkey-fingerprint "${OMNI_PRIVATE_KEY_EMAIL}" &> /dev/null || die "Failed to list secret keys."

  ## Export GPG key
  info "Exporting GPG key to file..."
  gpg \
    --quiet \
    --export-secret-key \
    --armor "${OMNI_PRIVATE_KEY_EMAIL}" > "${OMNI_PRIVATE_KEY_PATH}" || die "Failed to export key."

  ## Backup .gnupg folder
  cp -R "${HOME:-/root}/.gnupg" "${OMNI_BACKUP_DIR}/gnupg"

  success "GPG key setup complete."
}

###############################################################################
## Helper: Proxmox infrastructure provider key generation
###############################################################################
setup_infra_provider_key() {
  mkdir -p "${OMNI_KEY_DIR}"

  ## Check if infra provider key exists locally (either from backup extraction or previous run)
  if [[ -s ${OMNI_IP_KEY_PATH} ]]; then
    info "Proxmox InfraProvider key already exists at ${OMNI_IP_KEY_PATH}. Skipping generation."
    return 0
  fi

  ## Generating infra provider key.
  ## Declare first, then assign — `local output=$(...)` would mask the command's
  ## exit status (always 0 from `local`), so the `|| die` would never fire.
  info "Generating Proxmox InfraProvider Service Account inside Omni..."
  local output
  output=$(\
    HOME="${HOME:-/root}" \
    OMNI_ENDPOINT="${OMNI_API_ENDPOINT}" \
    OMNI_SERVICE_ACCOUNT_KEY="$(< "${OMNI_SA_KEY_PATH}")" \
    omnictl ip create proxmox-infra \
      --ttl 720h \
      --insecure-skip-tls-verify \
  ) || die "Failed to generate infra provider key"

  ## Extract new key from output
  local new_key
  new_key=$(echo "${output}" | grep '^OMNI_SERVICE_ACCOUNT_KEY=' | cut -d= -f2-)

  ## Validate that the new key was extracted
  if [[ -z "${new_key}" ]]; then
      die "Failed to extract OMNI_SERVICE_ACCOUNT_KEY from omnictl output '${output}'."
  fi

  ## Update the key file
  echo "${new_key}" > "${OMNI_IP_KEY_PATH}"

  success "Proxmox InfraProvider key ${OMNI_IP_NAME} successfully generated at ${OMNI_IP_KEY_PATH}."
}

###############################################################################
## Helper: Central backup restore
###############################################################################
restore_from_backup() {
  local latest_backup
  latest_backup=$(ls -t "${DOCKER_VOLUME_BACKUP_DIR}"/omni-backup-*.tar.gz 2>/dev/null | head -n 1 || true)
  mkdir -p "${OMNI_PERSISTENCE_DATA_DIR}" "${DOCKER_VOLUME_BACKUP_DIR}"

  ## Check if Omni data already exists locally (db file is a good marker)
  if [[ -f "${OMNI_DATA_DIR}/omni.db" ]]; then
    info "Omni database found locally. Skipping full backup restore."
    return 0
  fi

  ## Check if some backup archive exists
  if [[ -z "${latest_backup}" ]]; then
    info "No backup archive found in ${DOCKER_VOLUME_BACKUP_DIR}. Proceeding as fresh setup."
    return 0
  fi

  ## Extract backup archive
  info "Found Omni multi-volume backup: ${latest_backup}. Extracting..."
  tar -xzf "${latest_backup}" -C "${OMNI_PERSISTENCE_DATA_DIR}/" --strip-components=1 2> /dev/null

  success "Backup extraction successful."
}

###############################################################################
## Main Script
###############################################################################
info "===================================="
info " Omni Bootstrap "
info "===================================="

## Load environment files
info "Loading environment files..."
# shellcheck source=/dev/null
source "${OMNI_BOOTSTRAP_CONF}" || die "Bootstrap configuration file not found at ${OMNI_BOOTSTRAP_CONF}."

## Restore all data from the latest tarball (if on a fresh node)
info "Checking for Omni backup archive to restore..."
restore_from_backup

## Download static curl for internal healthchecks
info "Ensuring static curl for healthchecks is present..."
download_static_curl

## Download omnictl
info "Ensuring omnictl is present..."
download_omnictl

## Restore or generate new certificates
info "Ensuring certificates are present..."
setup_certificates

## Restore or generate new GPG keys
info "Ensuring GPG state is present..."
setup_gpg

## Create .env symlink for docker compose
ln -sf "${OMNI_BOOTSTRAP_CONF}" "${OMNI_LOCAL_DIR}/.env"

## Deploy Core Omni Service
info "Deploying core Omni service and waiting for API to become healthy..."
cd "${OMNI_LOCAL_DIR}"
docker compose up -d --wait omni 2> /dev/null || die "Failed to start Omni core service."

## Generate infra provider key
info "Generating Proxmox infrastructure provider key..."
setup_infra_provider_key

## Set permissions & ownership for newly generated key
chown -R "${OMNI_OWNER}" "${OMNI_CERT_DIR}"
chown -R "${OMNI_OWNER}" "${OMNI_KEY_DIR}"

## Deploy Remaining Services (Provider, Backup)
info "Deploying remaining Omni infrastructure stack..."
cd "${OMNI_LOCAL_DIR}"
OMNI_SERVICE_ACCOUNT_KEY="$(< "${OMNI_IP_KEY_PATH}")" \
docker compose up -d 2> /dev/null || die "Failed to deploy remaining compose stack."

success "===================================="
success " Omni Bootstrap complete!"
success "===================================="
