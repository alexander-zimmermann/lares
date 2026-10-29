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
## User management
###############################################################################
resource "pbs_user" "this" {
  userid  = "${var.username}@${var.realm}"
  enable  = var.enabled
  comment = var.comment

  ## Write-only: never in state or plan, so the version counter is the only rotation signal
  password_wo         = var.password
  password_wo_version = var.password != null ? var.password_version : null
}

## Tokens carry their own ACL in PBS; the secret is only returned on creation
resource "pbs_api_token" "this" {
  count = var.create_token ? 1 : 0

  userid     = pbs_user.this.userid
  token_name = var.token_name
  comment    = var.comment
}

## ACL for the user account
resource "pbs_acl" "this" {
  auth_id   = pbs_user.this.userid
  role      = var.role_id
  path      = var.path
  propagate = var.propagate
}

## Same ACL for the token
resource "pbs_acl" "token" {
  count = var.create_token ? 1 : 0

  auth_id   = pbs_api_token.this[0].tokenid
  role      = var.role_id
  path      = var.path
  propagate = var.propagate
}
