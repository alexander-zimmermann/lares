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
## OpenID Connect realm
###############################################################################
resource "proxmox_backup_server_realm_openid" "this" {
  provider = pbs

  realm      = var.realm
  issuer_url = var.issuer_url
  comment    = var.comment
  default    = var.default

  ## Stored in state: the provider has no write-only variant of the secret
  client_id  = var.client_id
  client_key = var.client_key
  scopes     = var.scopes

  username_claim = var.username_claim
  auto_create    = var.autocreate
}


###############################################################################
## User mapping
###############################################################################
## Created up front: PBS has no groups, and the ACL API rejects a user that
## does not exist yet
resource "proxmox_backup_server_user" "this" {
  provider = pbs
  for_each = var.users

  user_id = "${each.key}@${proxmox_backup_server_realm_openid.this.realm}"
  comment = var.comment
}

resource "proxmox_backup_server_acl" "this" {
  provider = pbs
  for_each = var.users

  user_id   = proxmox_backup_server_user.this[each.key].user_id
  role_id   = each.value.role_id
  path      = each.value.path
  propagate = each.value.propagate
}
