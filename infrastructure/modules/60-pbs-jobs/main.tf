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
## Verify jobs
###############################################################################
resource "proxmox_backup_server_verify_job" "this" {
  provider = pbs
  for_each = var.verify

  id       = each.key
  store    = each.value.store
  schedule = each.value.schedule
  comment  = each.value.comment

  ignore_verified = each.value.ignore_verified
  outdated_after  = each.value.outdated_after
}


###############################################################################
## Prune and sync jobs
###############################################################################
## The provider has no resource for either yet, so both are applied over SSH:
## create the job when `show` does not know it, update it otherwise. The
## inputs are the only triggers; the command output lands in the apply log.
locals {
  keep_names = ["last", "hourly", "daily", "weekly", "monthly", "yearly"]

  prune_scripts = {
    for id, job in var.prune : id => <<-BASH
      #!/usr/bin/env bash
      set -euo pipefail

      ARGS=(--store '${job.store}' --schedule '${job.schedule}'%{for k, v in job.keep} --keep-${k} ${v}%{endfor}%{if job.comment != null} --comment '${job.comment}'%{endif})
      if sudo proxmox-backup-manager prune-job show '${id}' > /dev/null 2>&1; then
        # Retention lines dropped from the manifest are removed from the job
        sudo proxmox-backup-manager prune-job update '${id}' "$${ARGS[@]}"%{for k in local.keep_names}%{if !contains(keys(job.keep), k)} --delete keep-${k}%{endif}%{endfor}
      else
        sudo proxmox-backup-manager prune-job create '${id}' "$${ARGS[@]}"
      fi
    BASH
  }

  sync_scripts = {
    for id, job in var.sync : id => <<-BASH
      #!/usr/bin/env bash
      set -euo pipefail

      ARGS=(--store '${job.store}' --remote-store '${job.remote_store}' --schedule '${job.schedule}' --remove-vanished ${job.remove_vanished}%{if job.comment != null} --comment '${job.comment}'%{endif})
      if sudo proxmox-backup-manager sync-job show '${id}' > /dev/null 2>&1; then
        sudo proxmox-backup-manager sync-job update '${id}' "$${ARGS[@]}"
      else
        sudo proxmox-backup-manager sync-job create '${id}' "$${ARGS[@]}"
      fi
    BASH
  }
}

resource "terraform_data" "prune" {
  for_each = var.prune

  ## Re-execute if any attribute changes
  triggers_replace = [each.value]

  connection {
    type        = "ssh"
    host        = var.ssh_hostname
    user        = var.ssh_username
    port        = var.ssh_port
    private_key = file(pathexpand(var.ssh_private_key))
    timeout     = "60s"
  }

  provisioner "remote-exec" {
    inline = [local.prune_scripts[each.key]]
  }
}

resource "terraform_data" "sync" {
  for_each = var.sync

  ## Re-execute if any attribute changes
  triggers_replace = [each.value]

  connection {
    type        = "ssh"
    host        = var.ssh_hostname
    user        = var.ssh_username
    port        = var.ssh_port
    private_key = file(pathexpand(var.ssh_private_key))
    timeout     = "60s"
  }

  provisioner "remote-exec" {
    inline = [local.sync_scripts[each.key]]
  }
}
