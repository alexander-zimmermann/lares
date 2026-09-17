###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.4.0"
    }
  }
}


###############################################################################
## ACME account, DNS plugin and certificate
###############################################################################
## PBS keeps ACME outside its API for the provider, so all three steps run
## over SSH. The script carries no secret: the plugin data (the Cloudflare
## token) arrives on stdin and is written to a root-only file for the
## duration of the `plugin add`; the DEBUG trace logs commands, not input.
locals {
  script_path = "/tmp/pbs_acme.sh"
  log_output  = "/tmp/pbs_acme.log"
  cert_path   = "/etc/proxmox-backup/proxy.pem"

  domains = concat([var.primary_domain], var.san_domains)

  plugin_data = join("\n", compact([
    var.cf_account_id != null && length(coalesce(var.cf_account_id, "")) > 0 ? "CF_Account_ID=${var.cf_account_id}" : "",
    var.cf_zone_id != null && length(coalesce(var.cf_zone_id, "")) > 0 ? "CF_Zone_ID=${var.cf_zone_id}" : "",
    "CF_Token=${var.cf_token}",
  ]))

  ## No `~` in the template directives: it would keep the heredoc indentation
  pbs_acme_script = <<-BASH
    #!/usr/bin/env bash
    set -euo pipefail

    # The plugin data comes first, before the log swallows stdin
    PLUGIN_DATA=$(mktemp)
    chmod 600 "$PLUGIN_DATA"
    cat > "$PLUGIN_DATA"

    # Send everything to the log file
    exec > ${local.log_output} 2>&1

    # Log every command executed, with timestamp and source info
    trap 'printf "+ [%(%F %T)T] %s:%d: %s\n" -1 "$(basename -- "$BASH_SOURCE")" "$LINENO" "$BASH_COMMAND" >&2' DEBUG

    DOMAINS=(${join(" ", local.domains)})

    # Account: registered once, the TOS prompt answered, no external binding
    if ! sudo proxmox-backup-manager acme account list | grep -qw '${var.account_name}'; then
      printf 'y\nn\n' | sudo proxmox-backup-manager acme account register '${var.account_name}' '${var.contact_email}' --directory '${var.acme_directory}' > /dev/null
    fi

    # DNS plugin: re-added whenever this script runs (a trigger changed), so a
    # rotated token lands without touching a command line — `plugin set` takes
    # the data as an argument, `add` reads it from a file
    if sudo proxmox-backup-manager acme plugin list | grep -qw '${var.dns_plugin_id}'; then
      sudo proxmox-backup-manager acme plugin remove '${var.dns_plugin_id}'
    fi
    sudo proxmox-backup-manager acme plugin add dns '${var.dns_plugin_id}' --api '${var.dns_api}' --data "$PLUGIN_DATA"
    rm -f "$PLUGIN_DATA"

    # Node: account and one --acmedomainN per name
    DOMAIN_FLAGS=()
    for i in "$${!DOMAINS[@]}"; do
      DOMAIN_FLAGS+=("--acmedomain$${i}" "domain=$${DOMAINS[$i]},plugin=${var.dns_plugin_id}")
    done
    sudo proxmox-backup-manager node update --acme 'account=${var.account_name}' "$${DOMAIN_FLAGS[@]}"

    # Certificate: order unless the current one is from the CA, covers exactly
    # these names and has more than 30 days left
    wanted=$(printf '%s\n' "$${DOMAINS[@]}" | sort | paste -sd,)
    # An unreadable certificate or one without names counts as "different"
    current=$({ sudo openssl x509 -noout -ext subjectAltName -in ${local.cert_path} 2>/dev/null || :; } | { grep -o 'DNS:[^,[:space:]]*' || :; } | sed 's/^DNS://' | sort | paste -sd,)
    if sudo openssl x509 -noout -issuer -in ${local.cert_path} | grep -q 'O=Proxmox Backup Server' \
      || [[ "$current" != "$wanted" ]] \
      || ! sudo openssl x509 -checkend 2592000 -noout -in ${local.cert_path}; then
      sudo proxmox-backup-manager acme cert order --force
    else
      echo "certificate is current for $wanted, no order"
    fi
  BASH
}

resource "terraform_data" "pbs_acme" {
  ## Re-execute if any attribute changes. The token enters as a digest only,
  ## a deliberate step away from the layer's version counters: rotation then
  ## re-applies by itself, and a SHA-256 of a random token reveals nothing
  triggers_replace = [
    var.account_name,
    var.contact_email,
    var.acme_directory,
    var.dns_plugin_id,
    var.dns_api,
    sha256(local.plugin_data),
    join(",", local.domains)
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
    content     = local.pbs_acme_script
    destination = local.script_path
  }

  ## base64 keeps the plugin data out of shell quoting on the way in
  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.script_path}",
      "printf '%s' '${base64encode(local.plugin_data)}' | base64 -d | /usr/bin/env bash ${local.script_path}"
    ]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key} -P ${var.ssh_port} ${var.ssh_username}@${var.ssh_hostname}:${local.log_output} ${local.log_output}"
  }
}

data "external" "pbs_acme_output" {
  depends_on = [terraform_data.pbs_acme]
  program    = ["bash", "-c", "cat ${local.log_output} | jq -R -s '{output: .}'"]
}
