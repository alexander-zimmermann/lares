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
## OpenID Connect realm
###############################################################################
resource "proxmox_realm_openid" "this" {
  realm      = var.realm
  issuer_url = var.issuer_url
  comment    = var.comment
  default    = var.default

  ## Write-only: the secret is sent to PVE but never lands in state or plan.
  ## PVE does not return it either, so the version counter is the only rotation signal.
  client_id             = var.client_id
  client_key_wo         = var.client_key
  client_key_wo_version = var.client_key_version
  scopes                = var.scopes

  username_claim = var.username_claim
  autocreate     = var.autocreate

  groups_claim      = var.groups_claim
  groups_autocreate = var.groups_autocreate
  groups_overwrite  = var.groups_overwrite
}


###############################################################################
## Group mapping
###############################################################################
## PVE names claim groups "<claim value>-<realm>" and rejects ACLs on groups that
## do not exist yet, so the groups are created here rather than on first login.
resource "proxmox_virtual_environment_group" "this" {
  for_each = var.groups

  group_id = "${each.key}-${var.realm}"
  comment  = var.comment
}

resource "proxmox_acl" "this" {
  for_each = var.groups

  group_id  = proxmox_virtual_environment_group.this[each.key].group_id
  role_id   = each.value.role_id
  path      = each.value.path
  propagate = each.value.propagate
}
