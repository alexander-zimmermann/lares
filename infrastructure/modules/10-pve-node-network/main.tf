###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.108.0"
    }
  }
}


###############################################################################
## Bonds
###############################################################################
## The provider doesn’t (yet) offer a native bond resource; the module supports bonds by
## either referencing existing bond interfaces or optionally creating them via SSH
## (editing/etc/network/interfaces and applying with ifreload -a).
locals {
  script_path = "/tmp/setup_bond.sh"
  log_output  = "/tmp/setup_bond.log"

  bond_setup_script = <<-BASH
    #!/usr/bin/env bash
    set -euo pipefail

    # Send everything to the log file
    exec > ${local.log_output} 2>&1

    # Log every command executed, with timestamp and source info
    trap 'printf "+ [%(%F %T)T] %s:%d: %s\n" -1 "$(basename -- "$BASH_SOURCE")" "$LINENO" "$BASH_COMMAND" >&2' DEBU

    # Safety backup
    sudo cp /etc/network/interfaces /etc/network/interfaces.tfbackup.$(date +%s)

    # Remove previous managed block for this bond (idempotent)
    if [ -f /etc/network/interfaces ]; then
      awk 'BEGIN{skip=0} /^# BEGIN TF BOND ${var.name}$/{skip=1} /^# END TF BOND ${var.name}$/{skip=0;next} skip==0{print}' /etc/network/interfaces > /tmp/interfaces.clean
      sudo mv /tmp/interfaces.clean /etc/network/interfaces
    fi

    sudo cat >>/etc/network/interfaces <<EOF
      # BEGIN TF BOND ${var.name}
      ${coalesce(var.autostart, true) ? "auto ${var.name}" : ""}

      # ${try(var.comment, "")}
      iface ${var.name} inet ${try(var.address, null) != null ? "static" : "manual"}
          bond-mode ${var.mode != null ? var.mode : "active-backup"}
          bond-slaves ${var.slaves != null ? join(" ", var.slaves) : ""}
          ${try(var.miimon, 100) != null ? format("bond-miimon %d", try(var.miimon, 100)) : ""}
          ${try(var.lacp_rate, null) != null ? format("bond-lacp-rate %s", var.lacp_rate) : ""}
          ${try(var.hash_policy, null) != null ? format("bond-xmit-hash-policy %s", var.hash_policy) : ""}
          ${try(var.primary, null) != null ? format("bond-primary %s", var.primary) : ""}
          ${try(var.mtu, null) != null ? format("mtu %d", var.mtu) : ""}
          ${try(var.address, null) != null ? format("address %s", var.address) : ""}
          ${try(var.gateway, null) != null ? format("gateway %s", var.gateway) : ""}

      # Optional IPv6 stanza
      ${try(var.address6, null) != null ? format("iface %s inet6 static\n    address %s\n    %s\n", var.name, var.address6, try(var.gateway6, null) != null ? format("gateway %s", var.gateway6) : "") : ""}# END TF BOND ${var.name}
    EOF

    # Apply live (ifupdown2)
    if command -v ifreload >/dev/null 2>&1; then
      sudo ifreload -a
    else
      echo 'WARNING: ifreload not present reboot may be required' >&2
    fi
  BASH
}

resource "terraform_data" "bond" {
  count = var.create_bond ? 1 : 0

  ## Re-execute if any attribute changes
  triggers_replace = [
    var.node,
    var.name,
    var.mode,
    join(",", var.slaves),
    tostring(var.miimon),
    var.lacp_rate,
    var.hash_policy,
    var.primary,
    tostring(var.mtu),
    var.address,
    var.address6,
    var.gateway,
    var.gateway6,
    tostring(var.autostart),
    var.comment
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
    content     = local.bond_setup_script
    destination = local.script_path
  }

  ## Per-bond remote exec to render/update stanza and reload networking
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

data "external" "bond_setup_output" {
  count      = var.create_bond ? 1 : 0
  depends_on = [terraform_data.bond]
  program    = ["bash", "-c", "cat ${local.log_output} | jq -R -s '{output: .}'"]
}

## Single "join" resource to depend on in other resources (handles for_each)
resource "terraform_data" "bonds_apply" {
  count = var.create_bond ? 1 : 0
  depends_on = [
    terraform_data.bond
  ]
}


###############################################################################
## VLAN interfaces
###############################################################################
resource "proxmox_network_linux_vlan" "vlans" {
  count = var.create_vlan ? 1 : 0

  ## If we create bonds via SSH, ensure they exist before VLANs like bond0.30
  depends_on = [terraform_data.bonds_apply]

  node_name = var.node
  name      = var.name
  address   = var.address
  address6  = var.address6
  autostart = var.autostart
  comment   = var.comment
  gateway   = var.gateway
  gateway6  = var.gateway6
  interface = var.interface
  mtu       = var.mtu
  vlan      = var.vlan
}


###############################################################################
## Bridges
###############################################################################
resource "proxmox_network_linux_bridge" "bridges" {
  count = var.create_bridge ? 1 : 0

  ## Ensure VLANs (and optionally bonds) are ready before we attach ports
  depends_on = [
    proxmox_network_linux_vlan.vlans,
    terraform_data.bonds_apply
  ]

  node_name  = var.node
  name       = var.name
  address    = var.address
  address6   = var.address6
  autostart  = var.autostart
  comment    = var.comment
  gateway    = var.gateway
  gateway6   = var.gateway6
  mtu        = var.mtu
  vlan_aware = var.vlan_aware
  ports      = var.ports != null ? sort(var.ports) : []
}
