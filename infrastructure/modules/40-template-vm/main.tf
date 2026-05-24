###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.107.0"
    }
  }
}


###############################################################################
##  Virtual machine templates
###############################################################################
resource "proxmox_virtual_environment_vm" "vm_template" {
  node_name = var.node
  name      = replace(var.name, "_", "-")
  vm_id     = var.vm_id
  template  = true
  started   = false

  description = var.description != null ? var.description : "Created by OpenTofu - ${timestamp()}"
  tags        = var.tags

  lifecycle {
    ignore_changes = [description]
  }

  bios          = var.bios
  machine       = var.machine_type
  tablet_device = var.tablet

  ## Boot order: Priority for primary disk, followed by the CD-ROM and Network if they exist.
  boot_order = var.boot_order != null ? var.boot_order : concat(
    [var.disk_interface],
    (var.image_id != null && strcontains(var.image_id, ":iso/")) ? [var.cdrom_interface] : [],
    (var.vnic_bridge != null) ? ["net0"] : []
  )

  agent {
    enabled = var.qemu_guest_agent
    timeout = "60s"
  }

  operating_system {
    type = var.os_type
  }

  cpu {
    cores = var.cores
    type  = var.vcpu_type
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_floating != null ? var.memory_floating : var.memory
  }

  vga {
    type   = var.display_type
    memory = var.display_memory
  }

  ## Only create EFI disk when using OVMF (UEFI)
  dynamic "efi_disk" {
    for_each = (var.bios == "ovmf" ? [1] : [])
    content {
      datastore_id      = var.efi_datastore != null ? var.efi_datastore : var.disk_datastore
      file_format       = var.efi_disk_format
      type              = var.efi_disk_type
      pre_enrolled_keys = var.secure_boot ? var.efi_disk_pre_enrolled_keys : false
    }
  }

  ## TPM 2.0 device for Windows 11 and other modern OS requiring TPM
  dynamic "tpm_state" {
    for_each = (var.enable_tpm ? [1] : [])
    content {
      datastore_id = var.tpm_datastore != null ? var.tpm_datastore : var.disk_datastore
      version      = var.tpm_version
    }
  }

  ## Disk: import from non-ISO images (qcow2, raw.xz, etc.)
  dynamic "disk" {
    for_each = (var.image_id != null && !strcontains(var.image_id, ":iso/")) ? [1] : []
    content {
      datastore_id = var.disk_datastore
      interface    = var.disk_interface
      import_from  = var.image_id
      size         = var.disk_size
      file_format  = var.disk_format
      cache        = var.disk_cache
      discard      = var.disk_discard
      iothread     = var.disk_iothread
      ssd          = var.disk_ssd
    }
  }

  ## For ISO images or when no image provided: create blank disk
  dynamic "disk" {
    for_each = (var.image_id == null || strcontains(var.image_id, ":iso/")) ? [1] : []
    content {
      datastore_id = var.disk_datastore
      interface    = var.disk_interface
      size         = var.disk_size
      file_format  = var.disk_format
      cache        = var.disk_cache
      discard      = var.disk_discard
      iothread     = var.disk_iothread
      ssd          = var.disk_ssd
    }
  }

  ## CD-ROM drive for OS installation ISO
  dynamic "cdrom" {
    for_each = (var.image_id != null && strcontains(var.image_id, ":iso/")) ? [1] : []
    content {
      file_id   = var.image_id
      interface = var.cdrom_interface
    }
  }

  dynamic "network_device" {
    for_each = var.vnic_bridge == null ? [] : [1]
    content {
      model = var.vnic_model

      ## Bridge only when non-empty; otherwise set null so the arg is omitted
      bridge = trimspace(coalesce(var.vnic_bridge, "")) != "" ? var.vnic_bridge : null

      ## VLAN only when provided and we're bridged
      vlan_id = (
        var.vlan_tag != null &&
        trimspace(coalesce(var.vnic_bridge, "")) != ""
      ) ? var.vlan_tag : null
    }
  }

  dynamic "initialization" {
    ## Render cloud-init initialization disk only when explicitly enabled AND at
    ## least one cloud-init data file (user/vendor/network/meta) is provided. This
    ## prevents creating an empty NoCloud disk for templates (e.g. Talos) that
    ## disable cloud-init or don't supply any snippets.
    for_each = (
      var.enable_cloud_init && (
        var.ci_user_data != null ||
        var.ci_vendor_data != null ||
        var.ci_network_data != null ||
        var.ci_meta_data != null
      )
    ) ? [1] : []
    content {
      datastore_id         = var.ci_datastore != null ? var.ci_datastore : var.disk_datastore
      interface            = var.ci_interface
      type                 = var.ci_datasource_type
      meta_data_file_id    = var.ci_meta_data
      user_data_file_id    = var.ci_user_data
      network_data_file_id = var.ci_network_data
      vendor_data_file_id  = var.ci_vendor_data
    }
  }
}
