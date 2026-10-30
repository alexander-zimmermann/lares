###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    pbs = {
      source  = "rfdrew/pbs"
      version = "~> 0.3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.4.0"
    }
  }
}


###############################################################################
## APT repositories
###############################################################################
## PBS installs the enterprise repository enabled and cannot remove it, so the
## resource takes over its entry and switches it. `pbs-no-subscription` stays
## in cloud-init, which needs it to install PBS in the first place.
data "pbs_apt_repositories" "this" {}

locals {
  enterprise = one([
    for r in data.pbs_apt_repositories.this.standard_repositories : r
    if r.handle == "enterprise"
  ])
}

resource "pbs_apt_repository" "enterprise" {
  file_path = local.enterprise.file_path
  index     = local.enterprise.index
  enabled   = var.enable_enterprise_repository
}


###############################################################################
## Subscription nag
###############################################################################
## PBS has no API for it, so it is applied over SSH: the nag is patched out of
## proxmoxlib.js by an APT hook after every proxmox-widget-toolkit install or
## upgrade.
locals {
  script_path = "/tmp/pbs_core.sh"
  log_output  = "/tmp/pbs_core.log"

  nag_hook   = "/etc/apt/apt.conf.d/no-nag-script"
  toolkit_js = "/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

  ## No `~` in the template directives: it would keep the heredoc indentation
  pbs_core_script = <<-BASH
    #!/usr/bin/env bash
    set -euo pipefail

    # Send everything to the log file
    exec > ${local.log_output} 2>&1

    # Log every command executed, with timestamp and source info
    trap 'printf "+ [%(%F %T)T] %s:%d: %s\n" -1 "$(basename -- "$BASH_SOURCE")" "$LINENO" "$BASH_COMMAND" >&2' DEBUG

    # Subscription nag
    %{if var.disable_subscription_nag}
    sudo tee ${local.nag_hook} > /dev/null <<'HOOK'
    DPkg::Post-Invoke { "if [ -s ${local.toolkit_js} ] && ! grep -q -F 'NoMoreNagging' ${local.toolkit_js}; then sed -i '/data\.status/{s/\!//;s/active/NoMoreNagging/}' ${local.toolkit_js}; fi" };
    HOOK
    %{else}
    sudo rm -f ${local.nag_hook}
    %{endif}

    # Reinstall the toolkit: runs the hook right away, or restores the original
    sudo apt-get --reinstall install -y proxmox-widget-toolkit > /dev/null
  BASH
}

resource "terraform_data" "pbs_core" {
  ## Re-execute if the attribute changes
  triggers_replace = [
    var.disable_subscription_nag
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
    content     = local.pbs_core_script
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

data "external" "pbs_core_output" {
  depends_on = [terraform_data.pbs_core]
  program    = ["bash", "-c", "cat ${local.log_output} | jq -R -s '{output: .}'"]
}
