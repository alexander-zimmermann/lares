#!/usr/bin/env bash
###############################################################################
## apcupsd UPS Monitor bootstrap script
###############################################################################
## Automates apcupsd initial setup, including configuration generation,
## custom shutdown script installation, and service activation.
##
## Prerequisites:
## - apcupsd installed.
## - Environment file in /etc/apcupsd/apcupsd-bootstrap.conf

set -euo pipefail

## Set environment file
APCUPSD_BOOTSTRAP_CONF="/etc/apcupsd/apcupsd-bootstrap.conf"

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
## Helper: Generate apcupsd.conf using sed on the default config
###############################################################################
configure_apcupsd() {
  local config="/etc/apcupsd/apcupsd.conf"

  ## Check if already configured
  if grep -q "^UPSNAME ${APCUPSD_UPSNAME}$" "${config}" 2>/dev/null; then
    info "apcupsd already configured for ${APCUPSD_UPSNAME}."
    return 0
  fi

  info "Configuring apcupsd..."

  ## Patch the default config in-place
  sed -i \
    -e "0,/^#*\s*UPSNAME/s|^#*\s*UPSNAME.*|UPSNAME ${APCUPSD_UPSNAME}|" \
    -e "s|^UPSCABLE.*|UPSCABLE usb|" \
    -e "s|^UPSTYPE.*|UPSTYPE ${APCUPSD_UPSTYPE}|" \
    -e "s|^DEVICE.*|DEVICE ${APCUPSD_DEVICE}|" \
    -e "s|^NISIP.*|NISIP ${APCUPSD_NISIP}|" \
    -e "s|^NISPORT.*|NISPORT ${APCUPSD_NISPORT}|" \
    -e "s|^BATTERYLEVEL.*|BATTERYLEVEL ${APCUPSD_BATTERYLEVEL}|" \
    -e "s|^MINUTES.*|MINUTES ${APCUPSD_MINUTES}|" \
    -e "s|^TIMEOUT.*|TIMEOUT ${APCUPSD_TIMEOUT}|" \
    "${config}"

  success "apcupsd.conf configured."
}

###############################################################################
## Helper: Install custom doshutdown script
###############################################################################
install_doshutdown() {
  local script="/etc/apcupsd/doshutdown"

  ## Check if already installed
  if [[ -f "${script}" ]] && grep -q "PVE_API_URL" "${script}" 2>/dev/null; then
    info "Custom doshutdown script already installed."
    return 0
  fi

  info "Installing custom doshutdown script..."
  cp /usr/local/bin/apcupsd-doshutdown.sh "${script}"
  chmod 755 "${script}"

  success "Custom doshutdown script installed."
}

###############################################################################
## Helper: Enable apcupsd service
###############################################################################
enable_service() {
  info "Enabling apcupsd service..."

  ## Debian requires ISCONFIGURED=yes before the daemon will start
  sed -i 's/^ISCONFIGURED=no/ISCONFIGURED=yes/' /etc/default/apcupsd

  systemctl enable --now apcupsd || die "Failed to enable apcupsd."

  success "apcupsd service enabled."
}

###############################################################################
## Helper: Wait for USB HID device and verify UPS connectivity
###############################################################################
verify_ups() {
  local hiddev="/dev/usb/hiddev0"
  local retries=30

  info "Waiting for USB HID device..."
  for _ in $(seq 1 "${retries}"); do
    if [[ -e "${hiddev}" ]]; then
      success "USB HID device found at ${hiddev}."
      ## Restart apcupsd so it picks up the device
      systemctl restart apcupsd
      sleep 2
      apcaccess status | head -10
      return 0
    fi
    sleep 2
  done

  info "USB HID device not found after ${retries} attempts. apcupsd may reconnect later."
}

###############################################################################
## Main Script
###############################################################################
info "===================================="
info " apcupsd UPS Monitor Bootstrap "
info "===================================="

## Load environment files
# shellcheck source=/dev/null
source "${APCUPSD_BOOTSTRAP_CONF}" || die "Bootstrap configuration file not found at ${APCUPSD_BOOTSTRAP_CONF}."

## Generate apcupsd configuration
info "Generating apcupsd configuration..."
configure_apcupsd

## Install custom shutdown script
info "Installing shutdown script..."
install_doshutdown

## Enable and start service
info "Activating apcupsd service..."
enable_service

## Verify UPS connectivity
verify_ups

success "===================================="
success " apcupsd Bootstrap complete!"
success "===================================="
