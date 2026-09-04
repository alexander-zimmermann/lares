###############################################################################
## Provider Packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112.0"
    }
  }
}


###############################################################################
## Proxmox Backup Server readiness
###############################################################################
locals {
  log_output = "/tmp/pbs-ready-${var.storage_id}.log"

  pbs_ready_script = <<-BASH
    #!/bin/bash
    set -euo pipefail

    exec > ${local.log_output} 2>&1

    PBS_URL="https://${var.server}:8007"
    PBS_USER="${var.username}@${var.realm}"
    PBS_PASS="${var.password}"
    PBS_DS="${var.datastore}"

    # Function to get a PBS API ticket, used for authentication in subsequent API calls
    get_ticket() {
      curl -sk --max-time 10 \
        --data-urlencode "username=$PBS_USER" \
        --data-urlencode "password=$PBS_PASS" \
        "$PBS_URL/api2/json/access/ticket" \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['ticket'])" 2>/dev/null
    }

    # Wait for PBS API to be reachable
    echo "Waiting for PBS API..."
    until TICKET=$(get_ticket) && [ -n "$TICKET" ]; do
      echo "  PBS API not ready, retrying in 15s..."
      sleep 15
    done

    # Poll PBS REST API until the backup datastore is available
    echo "Waiting for datastore '$PBS_DS'..."
    until curl -sk --max-time 10 \
      -H "Cookie: PBSAuthCookie=$TICKET" \
      "$PBS_URL/api2/json/admin/datastore" \
      | python3 -c "import sys,json; ds=[d['store'] for d in json.load(sys.stdin)['data']]; exit(0 if '$PBS_DS' in ds else 1)" 2>/dev/null; do
      echo "  Datastore not ready, retrying in 15s..."
      sleep 15
      TICKET=$(get_ticket)
    done

    echo "PBS is ready."
  BASH
}

resource "terraform_data" "pbs_ready" {
  ## Re-execute if any attribute changes
  triggers_replace = [
    var.server,
    var.username,
    var.password,
    var.datastore
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = local.pbs_ready_script
  }
}

data "external" "pbs_ready_output" {
  depends_on = [terraform_data.pbs_ready]
  program    = ["bash", "-c", "cat ${local.log_output} | jq -R -s '{output: .}'"]
}


###############################################################################
## Storage configuration
###############################################################################
resource "proxmox_storage_pbs" "this" {
  depends_on = [terraform_data.pbs_ready]

  id        = var.storage_id
  nodes     = var.nodes
  server    = var.server
  datastore = var.datastore

  username    = "${var.username}@${var.realm}"
  password    = var.password
  fingerprint = var.fingerprint
  content     = ["backup"]
}
