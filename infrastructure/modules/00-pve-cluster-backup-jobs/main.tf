###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.0"
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

  ## Host CPU/IO throttling — null keeps the Proxmox defaults
  zstd    = var.zstd
  ionice  = var.ionice
  bwlimit = var.bwlimit

  performance = var.max_workers == null ? null : {
    max_workers = var.max_workers
  }
}
