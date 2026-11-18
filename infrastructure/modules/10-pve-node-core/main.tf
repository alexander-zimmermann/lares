###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.123.0"
    }
  }
}


###############################################################################
## Basic settings
###############################################################################
resource "proxmox_virtual_environment_time" "this" {
  node_name = var.node
  time_zone = var.timezone
}

resource "proxmox_virtual_environment_dns" "this" {
  node_name = var.node
  domain    = var.dns_search_domain
  servers   = var.dns_servers
}


###############################################################################
## APT repositories
###############################################################################
## Enable no subscription repository
resource "proxmox_apt_standard_repository" "no_subscription" {
  node   = var.node
  handle = "no-subscription"
}

resource "proxmox_apt_repository" "enable_no_subscription" {
  node      = proxmox_apt_standard_repository.no_subscription.node
  file_path = proxmox_apt_standard_repository.no_subscription.file_path
  index     = proxmox_apt_standard_repository.no_subscription.index
  enabled   = var.enable_no_subscription_repository
}


## Disable enterprise repository
data "proxmox_apt_standard_repository" "enterprise" {
  handle = "enterprise"
  node   = var.node
}

resource "proxmox_apt_repository" "enable_enterprise" {
  node      = data.proxmox_apt_standard_repository.enterprise.node
  file_path = data.proxmox_apt_standard_repository.enterprise.file_path
  index     = data.proxmox_apt_standard_repository.enterprise.index
  enabled   = var.enable_enterprise_repository
}

## Disable ceph repository
data "proxmox_apt_standard_repository" "ceph" {
  handle = "ceph-squid-enterprise"
  node   = var.node
}

resource "proxmox_apt_repository" "enable_ceph" {
  node      = data.proxmox_apt_standard_repository.ceph.node
  file_path = data.proxmox_apt_standard_repository.ceph.file_path
  index     = data.proxmox_apt_standard_repository.ceph.index
  enabled   = var.enable_ceph_repository
}


###############################################################################
## Subscription Key
###############################################################################
resource "terraform_data" "set_subscription" {
  count = var.proxmox_subscription_key != "" ? 1 : 0

  triggers_replace = [
    var.proxmox_subscription_key
  ]

  connection {
    type        = "ssh"
    host        = var.ssh_hostname
    user        = var.ssh_username
    port        = var.ssh_port
    private_key = file(pathexpand(var.ssh_private_key))
    timeout     = "60s"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /usr/bin/pvesubscription set ${var.proxmox_subscription_key}"
    ]
  }
}


###############################################################################
## Local storage content types
###############################################################################
locals {
  content_types = join(",", sort(tolist(var.local_content_types)))
  script_path   = "/tmp/local_content_types.sh"
  log_output    = "/tmp/local_content_types.log"

  local_content_types_script = <<-BASH
    #!/usr/bin/env bash
    set -euo pipefail

    # Send everything to the log file
    exec > ${local.log_output} 2>&1

    # Log every command executed, with timestamp and source info
    trap 'printf "+ [%(%F %T)T] %s:%d: %s\n" -1 "$(basename -- "$BASH_SOURCE")" "$LINENO" "$BASH_COMMAND" >&2' DEBUG

    sudo /usr/sbin/pvesm set local --content ${local.content_types}
  BASH
}

resource "terraform_data" "local_content_types" {
  ## Re-execute if any attribute changes
  triggers_replace = [
    ## only re-runs when the membership changes (not the order)
    local.content_types
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
    content     = local.local_content_types_script
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

data "external" "local_content_type_output" {
  depends_on = [terraform_data.local_content_types]
  program    = ["bash", "-c", "cat ${local.log_output}| jq -R -s '{output: .}'"]
}


###############################################################################
## SMART exporter
###############################################################################
## Disk health for Prometheus: the Talos VMs see no physical disks, so the exporter runs on the host.
## Debian ships it in backports only; apt takes nothing else from there unless asked with -t.
## Each sudo call must match a line in /etc/sudoers.d/opentofu word for word (see the README); -n fails instead of prompting.
locals {
  smartctl_exporter_script_path = "/tmp/smartctl_exporter.sh"
  smartctl_exporter_script      = <<-BASH
    #!/usr/bin/env bash
    set -euo pipefail
    codename="$(awk -F= '$1 == "VERSION_CODENAME" { print $2 }' /etc/os-release)"
    printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: %s-backports\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n' "$codename" \
      | sudo -n tee /etc/apt/sources.list.d/debian-backports.sources >/dev/null
    sudo -n apt-get update -qq
    sudo -n apt-get install -y -qq -t "$codename-backports" prometheus-smartctl-exporter
    sudo -n systemctl enable --now smartctl_exporter.service
  BASH
}

resource "terraform_data" "smartctl_exporter" {
  triggers_replace = [sha256(local.smartctl_exporter_script)]

  ## apt-get update reads every source, so the repositories and the subscription must be settled first
  depends_on = [
    proxmox_apt_repository.enable_no_subscription,
    proxmox_apt_repository.enable_enterprise,
    proxmox_apt_repository.enable_ceph,
    terraform_data.set_subscription,
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
    content     = local.smartctl_exporter_script
    destination = local.smartctl_exporter_script_path
  }

  provisioner "remote-exec" {
    inline = ["/usr/bin/env bash ${local.smartctl_exporter_script_path}"]
  }
}
