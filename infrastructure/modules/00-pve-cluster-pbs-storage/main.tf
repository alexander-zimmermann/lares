###############################################################################
## Provider Packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.0"
    }
  }
}


###############################################################################
## Storage configuration
###############################################################################
resource "proxmox_storage_pbs" "this" {
  id        = var.storage_id
  nodes     = var.nodes
  server    = var.server
  datastore = var.datastore

  username    = "${var.username}@${var.realm}"
  password    = var.password
  fingerprint = var.fingerprint
  content     = ["backup"]
}
