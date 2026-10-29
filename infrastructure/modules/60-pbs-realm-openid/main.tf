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
## OpenID Connect realm
###############################################################################
resource "pbs_realm_openid" "this" {
  realm      = var.realm
  issuer_url = var.issuer_url
  comment    = var.comment
  default    = var.default

  ## Write-only: never in state or plan, so the version counter is the only rotation signal
  client_id             = var.client_id
  client_key_wo         = var.client_key
  client_key_wo_version = var.client_key_version
  scopes                = var.scopes

  username_claim = var.username_claim
  autocreate     = var.autocreate
}


###############################################################################
## User mapping
###############################################################################
## Created up front: PBS has no groups, and the ACL API rejects a user that
## does not exist yet
resource "pbs_user" "this" {
  for_each = var.users

  userid  = "${each.key}@${pbs_realm_openid.this.realm}"
  comment = var.comment
}

resource "pbs_acl" "this" {
  for_each = var.users

  auth_id   = pbs_user.this[each.key].userid
  role      = each.value.role_id
  path      = each.value.path
  propagate = each.value.propagate
}
