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
## User management
###############################################################################
resource "proxmox_backup_server_user" "this" {
  provider = pbs

  user_id = "${var.username}@${var.realm}"
  enable  = var.enabled
  comment = var.comment
}

## Password over SSH until the provider carries it (jkossis/terraform-provider-proxmox#7).
## The version counter is the only trigger, so the password itself stays out of state.
resource "terraform_data" "password" {
  count = var.password != null ? 1 : 0

  triggers_replace = [var.password_version]

  ## A recreated user starts without a password
  lifecycle {
    replace_triggered_by = [proxmox_backup_server_user.this]
  }

  connection {
    type        = "ssh"
    host        = var.ssh_hostname
    user        = var.ssh_username
    port        = var.ssh_port
    private_key = file(pathexpand(var.ssh_private_key))
    timeout     = "60s"
  }

  ## base64 keeps the value out of shell quoting, the pipe keeps it out of the
  ## argv that sudo logs; PBS hashes it on receipt
  provisioner "remote-exec" {
    inline = [
      "printf '%s' '${base64encode(var.password)}' | base64 -d | sudo sh -c 'proxmox-backup-manager user update \"$1\" --password \"$(cat)\"' sh '${proxmox_backup_server_user.this.user_id}'"
    ]
  }
}

## Tokens carry their own ACL in PBS; the secret is only returned on creation
resource "proxmox_backup_server_user_token" "this" {
  count    = var.create_token ? 1 : 0
  provider = pbs

  user_id    = proxmox_backup_server_user.this.user_id
  token_name = var.token_name
  comment    = var.comment
}

## ACL for the user account
resource "proxmox_backup_server_acl" "this" {
  provider = pbs

  user_id   = proxmox_backup_server_user.this.user_id
  role_id   = var.role_id
  path      = var.path
  propagate = var.propagate
}

## Same ACL for the token
resource "proxmox_backup_server_acl" "token" {
  count    = var.create_token ? 1 : 0
  provider = pbs

  user_id   = proxmox_backup_server_user_token.this[0].id
  role_id   = var.role_id
  path      = var.path
  propagate = var.propagate
}
