###############################################################################
## Provider Packages
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
## User management
###############################################################################
resource "proxmox_virtual_environment_role" "this" {
  count      = var.create_role ? 1 : 0
  role_id    = var.role_id
  privileges = var.role_privileges
}

resource "proxmox_virtual_environment_user" "this" {
  user_id    = "${var.username}@${var.realm}"
  password   = var.password
  enabled    = var.enabled
  first_name = var.first_name
  last_name  = var.last_name
  email      = var.email
  comment    = var.comment

  lifecycle {
    ## Avoid perpetual diffs
    ## acl: managed separately via proxmox_acl resource
    ## password: can only be set with ticket (not API token) - ignore updates after creation
    ignore_changes = [acl, password]
  }
}

resource "proxmox_user_token" "this" {
  count                 = var.create_token ? 1 : 0
  token_name            = var.token_name
  user_id               = proxmox_virtual_environment_user.this.user_id
  privileges_separation = var.privileges_separation
  comment               = var.comment
}

## ACL for the user account
resource "proxmox_acl" "this" {
  user_id   = proxmox_virtual_environment_user.this.user_id
  role_id   = var.create_role ? proxmox_virtual_environment_role.this[0].role_id : var.role_id
  path      = var.path
  propagate = var.propagate
}

## Separate ACL for the token (only if privileges_separation is enabled)
resource "proxmox_acl" "token" {
  count     = var.create_token && var.privileges_separation ? 1 : 0
  token_id  = proxmox_user_token.this[0].id
  role_id   = var.create_role ? proxmox_virtual_environment_role.this[0].role_id : var.role_id
  path      = var.path
  propagate = var.propagate
}
