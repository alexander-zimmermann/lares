###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source                = "bpg/proxmox"
      version               = "~> 0.111.0"
      configuration_aliases = [proxmox.root]
    }
  }
}


###############################################################################
## ACME account & ACME DNS plugin
###############################################################################
## Cluster-level ACME account
resource "proxmox_acme_account" "this" {
  provider     = proxmox.root
  name         = var.account_name
  contact      = var.contact_email
  directory    = var.acme_directory
  tos          = var.acme_tos_url
  eab_kid      = var.acme_eab_kid
  eab_hmac_key = var.acme_eab_hmac_key
}

## Build plugin data map (Cloudflare by default)
locals {
  cf_data = merge(
    var.cf_token != null && length(var.cf_token) > 0 ? { CF_Token = var.cf_token } : {},
    var.cf_zone_id != null && length(var.cf_zone_id) > 0 ? { CF_Zone_ID = var.cf_zone_id } : {},
    var.cf_account_id != null && length(var.cf_account_id) > 0 ? { CF_Account_ID = var.cf_account_id } : {}
  )

  plugin_data = length(var.dns_plugin_data) > 0 ? var.dns_plugin_data : (
    var.dns_api == "cf" ? local.cf_data : {}
  )
}

## Cluster-level ACME DNS plugin (Cloudflare default)
resource "proxmox_acme_dns_plugin" "this" {
  plugin = var.dns_plugin_id
  api    = var.dns_api
  data   = local.plugin_data

  disable          = var.dns_plugin_disable
  validation_delay = var.dns_plugin_validation_delay
}


###############################################################################
## Certificate issuing
###############################################################################
## The provider exposes resources for the ACME account and ACME DNS plugin,
## but does not yet expose a resource to assign domains to nodes / order certs.
## See: https://github.com/bpg/terraform-provider-proxmox/issues/2157
locals {
  script_path = "/tmp/acme_order.sh"
  log_output  = "/tmp/acme_order.log"

  acme_order_script = <<-BASH
    #!/bin/bash
    set -euo pipefail

    # Send everything to the log file
    exec > ${local.log_output} 2>&1

    # Log every command executed, with timestamp and source info
    trap 'printf "+ [%(%F %T)T] %s:%d: %s\n" -1 "$(basename -- "$BASH_SOURCE")" "$LINENO" "$BASH_COMMAND" >&2' DEBUG

    # Build Bash array from the domain list
    ACME_DOMAINS="${var.primary_domain}${length(var.san_domains) > 0 ? ",${join(",", var.san_domains)}" : ""}"
    readarray -t DOMAINS <<< "$(echo "$${ACME_DOMAINS}" | tr ',' '\n' | xargs -n1)"

    # Construct domain flags for certificate issuing
    DOMAIN_FLAGS=()
    for i in $${!DOMAINS[@]}; do
      DOMAIN_FLAGS+=("--acmedomain$${i}" "domain=$${DOMAINS[$i]},plugin=${proxmox_acme_dns_plugin.this.plugin}")
    done

    # Apply ACME account and domains
    sudo /usr/bin/pvenode config set \
      --acme "account=${proxmox_acme_account.this.name}" \
      "$${DOMAIN_FLAGS[@]}"

    # Force order / renewal of the certificate
    sudo /usr/bin/pvenode acme cert order --force
  BASH
}

resource "terraform_data" "acme_order" {
  ## Ensure ACME account & plugin are created first
  depends_on = [
    proxmox_acme_account.this,
    proxmox_acme_dns_plugin.this
  ]

  ## Re-execute if any attribute changes
  triggers_replace = [
    join(",", compact(concat([var.primary_domain], var.san_domains))),
    proxmox_acme_account.this.name,
    proxmox_acme_dns_plugin.this.plugin
  ]

  connection {
    type        = "ssh"
    host        = var.ssh_hostname
    user        = var.ssh_username
    port        = var.ssh_port
    private_key = file(pathexpand(var.ssh_private_key))
    timeout     = "60s"
  }

  provisioner "file" {
    content     = local.acme_order_script
    destination = local.script_path
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.script_path}",
      "/usr/bin/env bash ${local.script_path}"
    ]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key} -P ${var.ssh_port} ${var.ssh_username}@${var.ssh_hostname}:${local.log_output} ${local.log_output}"
  }
}

data "external" "acme_order_output" {
  depends_on = [terraform_data.acme_order]
  program    = ["bash", "-c", "cat ${local.log_output}| jq -R -s '{output: .}'"]
}
