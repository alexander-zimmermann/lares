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
## Local values for MAC address generation
###############################################################################
locals {
  ## Deterministic MAC address generation for VMs
  ## 1st Byte: 02 (locally administered)
  ## 2nd Byte: 01 (VM), 02 (Container)
  ## 3rd-5th Byte: VM_ID (24 bits, split into 3 bytes)
  ## 6th Byte: NIC index (0, 1, 2, ...)
  generated_mac_addresses = {
    for idx, nic in var.network_interfaces : idx => (
      nic.mac_address != null ? nic.mac_address : format(
        "02:01:%02x:%02x:%02x:%02x",
        floor(var.vm_id / 65536) % 256, # ID Byte 1 (most significant)
        floor(var.vm_id / 256) % 256,   # ID Byte 2 (middle)
        var.vm_id % 256,                # ID Byte 3 (least significant)
        idx                             # NIC index
      )
    )
  }
}


###############################################################################
##  Virtual machine clones
###############################################################################
resource "proxmox_virtual_environment_vm" "vm" {
  node_name = var.node
  name      = replace(var.name, "_", "-")
  vm_id     = var.vm_id

  description = var.description != null ? var.description : "Created by OpenTofu - ${timestamp()}"
  tags        = var.tags
  protection  = var.protection

  bios          = var.bios
  machine       = var.machine_type
  tablet_device = var.tablet

  clone {
    node_name = var.template_node
    vm_id     = var.template_id
    full      = var.full_clone
    retries   = var.clone_retries
  }

  dynamic "agent" {
    for_each = var.agent_override ? [1] : []
    content {
      enabled = var.qemu_guest_agent
      timeout = var.wait_for_agent ? "5m" : "5s"
    }
  }

  dynamic "cpu" {
    for_each = var.override_cpu ? [1] : []
    content {
      cores = var.cores
      type  = var.vcpu_type
    }
  }

  dynamic "memory" {
    for_each = var.override_memory ? [1] : []
    content {
      dedicated = var.memory
      floating  = var.memory_floating != null ? var.memory_floating : var.memory
    }
  }

  dynamic "vga" {
    for_each = var.override_vga ? [1] : []
    content {
      type   = var.display_type
      memory = var.display_memory
    }
  }

  dynamic "efi_disk" {
    for_each = var.efi_disk_override ? [1] : []
    content {
      datastore_id      = var.efi_datastore != null ? var.efi_datastore : try(var.disks[0].disk_datastore, var.ci_datastore)
      file_format       = var.efi_disk_format
      type              = var.efi_disk_type
      pre_enrolled_keys = var.efi_disk_pre_enrolled_keys
    }
  }

  dynamic "disk" {
    for_each = var.disks
    content {
      datastore_id = disk.value.disk_datastore
      interface    = disk.value.disk_interface
      size         = disk.value.disk_size
      file_format  = disk.value.disk_format
      cache        = disk.value.disk_cache
      iothread     = disk.value.disk_iothread
      ssd          = disk.value.disk_ssd
      discard      = disk.value.disk_discard
    }
  }

  dynamic "network_device" {
    for_each = var.network_interfaces
    content {
      model       = network_device.value.vnic_model
      bridge      = network_device.value.vnic_bridge
      vlan_id     = network_device.value.vlan_tag
      mac_address = network_device.value.mac_address != null ? network_device.value.mac_address : local.generated_mac_addresses[network_device.key]
    }
  }

  dynamic "usb" {
    for_each = var.usb_devices
    content {
      host    = usb.value.host
      mapping = usb.value.mapping
      usb3    = usb.value.usb3
    }
  }

  dynamic "initialization" {
    ## Render cloud-init initialization disk only when explicitly enabled AND at
    ## least one cloud-init data file (user/vendor/network/meta) is provided. This
    ## prevents creating an empty NoCloud disk for templates (e.g. Talos) that
    ## disable cloud-init or don't supply any snippets.
    for_each = (
      var.cloud-init_override && (
        var.ci_user_data != null ||
        var.ci_vendor_data != null ||
        var.ci_network_data != null ||
        var.ci_meta_data != null
      )
    ) ? [1] : []
    content {
      datastore_id         = var.ci_datastore
      type                 = var.ci_datasource_type
      meta_data_file_id    = var.ci_meta_data
      network_data_file_id = var.ci_network_data
      user_data_file_id    = var.ci_user_data
      vendor_data_file_id  = var.ci_vendor_data
    }
  }

  on_boot = var.start_on_boot
  started = var.start_on_create

  dynamic "startup" {
    for_each = (var.start_on_boot == true ? [1] : [])
    content {
      order      = var.start_order
      up_delay   = var.start_delay
      down_delay = var.shutdown_delay
    }
  }

  ## Cloud-init SSH keys will cause a forced replacement, this is expected
  ## behavior see https://github.com/bpg/terraform-provider-proxmox/issues/373
  lifecycle {
    ignore_changes = [initialization, description]
  }
}


###############################################################################
## Windows NIC metrics through the guest agent
###############################################################################
## bpg can't run commands in a guest (bpg/terraform-provider-proxmox#1576), so qm guest exec runs over SSH
locals {
  ## Windows shows MAC addresses upper case with dashes
  nic_windows_macs = {
    for idx, mac in local.generated_mac_addresses : idx => upper(replace(mac, ":", "-"))
  }

  ## PowerShell per NIC that sets an IPv4 metric, keyed by index; the adapter is found by MAC
  nic_ipv4_metric_scripts = {
    for idx, nic in var.network_interfaces : idx => <<-POWERSHELL
      $ErrorActionPreference = 'Stop'
      $nic = Get-NetAdapter | Where-Object MacAddress -eq '${local.nic_windows_macs[idx]}'
      Set-NetIPInterface -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -InterfaceMetric ${nic.ipv4_metric}
    POWERSHELL
    if nic.ipv4_metric != null
  }
}

resource "terraform_data" "nic_ipv4_metric" {
  for_each = local.nic_ipv4_metric_scripts

  ## Re-run for a new VM or a changed script (MAC, metric)
  triggers_replace = [proxmox_virtual_environment_vm.vm.id, sha256(each.value)]

  connection {
    type        = "ssh"
    host        = var.ssh_hostname
    user        = var.ssh_username
    port        = var.ssh_port
    private_key = file(pathexpand(var.ssh_private_key))
    timeout     = "60s"
  }

  ## -EncodedCommand keeps the script clear of shell quoting; qm always exits 0, so python3 returns the guest exit code
  provisioner "remote-exec" {
    inline = [
      "sudo -n qm guest exec ${var.vm_id} --timeout 60 -- powershell.exe -NoProfile -NonInteractive -EncodedCommand ${textencodebase64(each.value, "UTF-16LE")} | python3 -c 'import json,sys; r=json.load(sys.stdin); sys.stderr.write(r.get(\"err-data\", \"\")); sys.exit(r.get(\"exitcode\", 1))'"
    ]
  }
}
