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
## ACME account & ACME DNS plugin
###############################################################################
## Registration agrees to the terms of service the directory currently names
data "pbs_acme_tos" "this" {
  directory = var.acme_directory
}

## Destroying or replacing the account deactivates it at the CA
resource "pbs_acme_account" "this" {
  name      = var.account_name
  contact   = var.contact_email
  directory = var.acme_directory
  tos_url   = data.pbs_acme_tos.this.url
}

## Build plugin data map (Cloudflare)
locals {
  plugin_data = merge(
    { CF_Token = var.cf_token },
    var.cf_zone_id != null && length(var.cf_zone_id) > 0 ? { CF_Zone_ID = var.cf_zone_id } : {},
    var.cf_account_id != null && length(var.cf_account_id) > 0 ? { CF_Account_ID = var.cf_account_id } : {}
  )
}

resource "pbs_acme_plugin" "this" {
  id   = var.dns_plugin_id
  api  = var.dns_api
  data = local.plugin_data
}


###############################################################################
## Certificate
###############################################################################
locals {
  domains = concat([var.primary_domain], var.san_domains)
}

resource "pbs_node_acme" "this" {
  account = pbs_acme_account.this.name
  domains = [for d in local.domains : { domain = d, plugin = pbs_acme_plugin.this.id }]
}

## Ordered on create and whenever the names change; PBS renews it itself
resource "pbs_node_certificate" "this" {
  source = "acme"

  triggers = {
    domains = join(",", sort([for d in pbs_node_acme.this.domains : d.domain]))
  }
}
