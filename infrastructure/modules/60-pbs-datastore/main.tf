###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    pbs = {
      source  = "rfdrew/pbs"
      version = "~> 0.2.0"
    }
  }
}


###############################################################################
## Datastore
###############################################################################
resource "pbs_datastore" "this" {
  name    = var.name
  path    = var.path
  comment = var.comment

  ## Create-only: adopt a chunk store the path already carries (NFS across rebuilds)
  reuse_datastore = var.reuse_datastore

  gc_schedule = var.gc_schedule

  ## A datastore holds the backups: never let a plan remove or replace it
  lifecycle {
    prevent_destroy = true
  }
}
