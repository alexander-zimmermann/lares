#!/usr/bin/env bash
###############################################################################
## apcupsd doshutdown script - Proxmox host shutdown via API
###############################################################################
## Called by apcupsd when battery reaches critical level. Triggers a graceful
## shutdown of the Proxmox node via the Proxmox REST API. The node shutdown
## process will stop all VMs/CTs (including this monitor VM) before powering
## off the host.

set -euo pipefail

APCUPSD_BOOTSTRAP_CONF="/etc/apcupsd/apcupsd-bootstrap.conf"

## Load configuration
# shellcheck source=/dev/null
source "${APCUPSD_BOOTSTRAP_CONF}" || exit 1

logger -t apcupsd "CRITICAL: UPS battery critical — shutting down Proxmox node ${PVE_NODE_NAME}"

## Shut down the Proxmox node via API
curl -sk --fail --max-time 30 \
  -X POST \
  -H "Authorization: PVEAPIToken=${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}" \
  "${PVE_API_URL}/api2/json/nodes/${PVE_NODE_NAME}/status" \
  -d "command=shutdown" \
  && logger -t apcupsd "Proxmox node ${PVE_NODE_NAME} shutdown initiated." \
  || logger -t apcupsd "ERROR: Failed to shut down Proxmox node ${PVE_NODE_NAME}."

exit 0
