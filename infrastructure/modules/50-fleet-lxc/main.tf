###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.109.0"
    }
  }
}


###############################################################################
## Local values for MAC address generation
###############################################################################
locals {
  # Deterministic MAC address generation for Containers
  # 1st Byte: 02 (locally administered)
  # 2nd Byte: 02 (Container), 01 (VM)
  # 3rd-5th Byte: Container_ID (24 bits, split into 3 bytes)
  # 6th Byte: NIC index (0, 1, 2, ...)
  generated_mac_addresses = {
    for idx, nic in var.network_interfaces : idx => (
      nic.mac_address != null ? nic.mac_address : format(
        "02:02:%02x:%02x:%02x:%02x",
        floor(var.lxc_id / 65536) % 256, # ID Byte 1 (most significant)
        floor(var.lxc_id / 256) % 256,   # ID Byte 2 (middle)
        var.lxc_id % 256,                # ID Byte 3 (least significant)
        idx                              # NIC index
      )
    )
  }
}


###############################################################################
##  Container clones
###############################################################################
resource "proxmox_virtual_environment_container" "lxc" {
  node_name     = var.node
  vm_id         = var.lxc_id
  unprivileged  = var.unprivileged
  start_on_boot = var.start_on_boot
  started       = var.start_on_create

  description = var.description
  tags        = var.tags
  protection  = var.protection

  clone {
    datastore_id = var.datastore
    vm_id        = var.template_id
    node_name    = var.template_node
  }

  dynamic "cpu" {
    for_each = var.override_cpu ? [1] : []
    content {
      cores        = var.cores
      architecture = var.vcpu_architecture
    }
  }

  dynamic "memory" {
    for_each = var.override_memory ? [1] : []
    content {
      dedicated = var.memory
      swap      = var.memory_swap
    }
  }

  dynamic "mount_point" {
    for_each = (var.mountpoint != null ? var.mountpoint : [])
    content {
      volume    = mount_point.value.mp_volume
      size      = mount_point.value.mp_size
      path      = mount_point.value.mp_path
      backup    = mount_point.value.mp_backup
      read_only = mount_point.value.mp_read_only
    }
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      name        = network_interface.value.vnic_name
      bridge      = network_interface.value.vnic_bridge
      vlan_id     = network_interface.value.vlan_tag
      mac_address = network_interface.value.mac_address != null ? network_interface.value.mac_address : local.generated_mac_addresses[network_interface.key]
    }
  }

  initialization {
    hostname = replace(var.name, "_", "-")

    dynamic "dns" {
      for_each = var.override_dns ? [1] : []
      content {
        domain  = jsonencode(var.dns_search_domain)
        servers = var.dns_servers
      }
    }

    dynamic "ip_config" {
      for_each = length(var.ipv4) > 0 ? [1] : []
      content {
        dynamic "ipv4" {
          for_each = var.ipv4
          content {
            address = ipv4.value.ipv4_address
            gateway = ipv4.value.ipv4_gateway
          }
        }
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

  dynamic "startup" {
    for_each = (var.start_on_boot == true ? [1] : [])
    content {
      order      = var.start_order
      up_delay   = var.start_delay
      down_delay = var.shutdown_delay
    }
  }
}
