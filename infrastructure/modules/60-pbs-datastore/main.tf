###############################################################################
## Provider packages
###############################################################################
## `pbs` is the jkossis/proxmox provider (Proxmox Backup Server); the resource
## types keep their `proxmox_backup_server_` prefix, so each one names it
terraform {
  required_providers {
    pbs = {
      source  = "jkossis/proxmox"
      version = "~> 1.1.0"
    }
  }
}


###############################################################################
## Datastore
###############################################################################
resource "proxmox_backup_server_datastore" "this" {
  provider = pbs

  name    = var.name
  path    = var.path
  comment = var.comment

  ## Create-only: adopt a chunk store the path already carries (NFS across rebuilds)
  reuse_datastore = var.reuse_datastore

  gc_schedule = var.gc_schedule

  ## A datastore holds the backups: never let a plan remove or replace it.
  ## The resource is authoritative otherwise: an attribute set in the UI and
  ## not declared here is removed on the next apply.
  lifecycle {
    prevent_destroy = true
  }
}
