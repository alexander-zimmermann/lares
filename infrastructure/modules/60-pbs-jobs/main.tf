###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    pbs = {
      source  = "rfdrew/pbs"
      version = "~> 0.3.0"
    }
  }
}


###############################################################################
## Verify jobs
###############################################################################
resource "pbs_verify_job" "this" {
  for_each = var.verify

  id       = each.key
  store    = each.value.store
  schedule = each.value.schedule
  comment  = each.value.comment

  ignore_verified = each.value.ignore_verified
  outdated_after  = each.value.outdated_after
}


###############################################################################
## Prune jobs
###############################################################################
resource "pbs_prune_job" "this" {
  for_each = var.prune

  id       = each.key
  store    = each.value.store
  schedule = each.value.schedule
  keep     = each.value.keep
}


###############################################################################
## Sync jobs
###############################################################################
## Without `remote`, a job pulls between two datastores of this PBS
resource "pbs_sync_job" "this" {
  for_each = var.sync

  id           = each.key
  store        = each.value.store
  remote_store = each.value.remote_store
  schedule     = each.value.schedule

  remove_vanished = each.value.remove_vanished
}
