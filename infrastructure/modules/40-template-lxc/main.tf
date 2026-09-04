###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112.0"
    }
  }
}


###############################################################################
##  Container templates
###############################################################################
resource "proxmox_virtual_environment_container" "lxc_template" {
  node_name     = var.node
  vm_id         = var.lxc_id
  unprivileged  = var.unprivileged
  template      = true
  started       = var.started
  start_on_boot = false

  description = var.description
  tags        = var.tags

  lifecycle {
    ignore_changes = [description]
  }

  operating_system {
    template_file_id = var.image_id
    type             = var.os_type
  }

  cpu {
    cores        = var.cores
    architecture = var.vcpu_architecture
  }

  memory {
    dedicated = var.memory
    swap      = var.memory_swap
  }

  disk {
    datastore_id = var.disk_datastore
    size         = var.disk_size
  }

  network_interface {
    name = var.vnic_name

    ## Bridge only when non-empty; otherwise set null so the arg is omitted
    bridge = trimspace(coalesce(var.vnic_bridge, "")) != "" ? var.vnic_bridge : null

    ## VLAN only when provided and we're bridged
    vlan_id = (
      var.vlan_tag != null &&
      trimspace(coalesce(var.vnic_bridge, "")) != ""
    ) ? var.vlan_tag : null
  }

  initialization {
    hostname = replace(var.name, "_", "-")

    dns {
      domain  = length(var.dns_search_domain) > 0 ? jsonencode(var.dns_search_domain) : null
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dynamic "user_account" {
      for_each = (
        (var.ssh_public_key != null && trimspace(var.ssh_public_key) != "") ||
        (var.password != null && trimspace(var.password) != "")
      ) ? [1] : []

      content {
        keys     = (var.ssh_public_key != null && trimspace(var.ssh_public_key) != "") ? [file(pathexpand(var.ssh_public_key))] : []
        password = (var.password != null && trimspace(var.password) != "") ? var.password : null
      }
    }
  }
}
