###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0"
    }
  }
}


###############################################################################
## Backup job
###############################################################################
resource "proxmox_backup_job" "this" {
  id       = var.job_id
  schedule = var.schedule
  storage  = var.storage
  vmid     = var.vmids
  mode     = var.mode
  compress = var.compress
}
