###############################################################################
## General VM variables
###############################################################################
variable "node" {
  description = <<EOT
    Name of the Proxmox node where the VM will be provisioned. This should
    match the node name as defined in your Proxmox cluster (e.g., `pve`).
  EOT
  type        = string

  validation {
    condition     = length(var.node) > 0
    error_message = "node must be a non-empty string."
  }
}

variable "name" {
  description = <<EOT
    The virtual machine name. Must be alphanumeric and may include dashes (`-`)
    and underscores (`_`). Underscores will be automatically replaced with dashes
    for DNS-compliant hostname. If not set, defaults to the Proxmox naming
    convention (e.g., `Copy-of-VM-<template_name>`).
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-zA-Z0-9_-]+$", var.name))
    error_message = "name must be null or an alphanumeric string (may contain dashes and underscores)."
  }
}

variable "vm_id" {
  description = <<EOT
    Optional explicit VM ID. If null, Proxmox will automatically assign a free
    ID from the cluster. Provide an explicit value to guarantee a stable,
    predictable VM numbering scheme.
  EOT
  type        = number
  default     = null

  validation {
    condition = var.vm_id == null || (
      floor(var.vm_id) == var.vm_id && var.vm_id >= 100 && var.vm_id <= 999999999
    )
    error_message = "vm_id must be null or an integer in the range 100..999999999."
  }
}

variable "description" {
  description = <<EOT
    Optional human-readable description for the VM. This text appears in the
    Proxmox UI and helps identify the VM’s purpose or role. If provided, it
    will overwrite the description inherited from the source template. If null,
    the template’s description (if any) will be retained.
  EOT

  type    = string
  default = null
}

variable "tags" {
  description = <<EOT
    Optional list of tags to assign to the VM in Proxmox. Tags allow filtering
    and grouping in the UI (e.g., by environment, application, or owner).
    If provided, these tags will overwrite any tags inherited from the template.
    If null or empty, the VM will keep the template’s tags (if present).
  EOT
  type        = list(string)
  default     = null

  validation {
    condition     = var.tags == null || alltrue([for t in var.tags : length(trimspace(t)) > 0])
    error_message = "Each tag must be a non-empty string."
  }
}


###############################################################################
## Template and cloning variables
###############################################################################
variable "template_node" {
  description = <<EOT
    Name of Proxmox node where the template resides. This should match the node
    name as defined in your Proxmox cluster (e.g., `pve`).
  EOT
  type        = string
  default     = null
}

variable "template_id" {
  description = <<EOT
     Numeric identifier of the Proxmox VM template to clone from. This should
    reference an existing VM template on the specified `template_node` and must
    match the `template_id` output from the `pve_vm_template` module. Required
    for creating a clone.
  EOT
  type        = number

  validation {
    condition     = var.template_id >= 100
    error_message = "template_id must be >= 100 (Proxmox reserves IDs below 100)."
  }
}

variable "full_clone" {
  description = <<EOT
      Whether to create a full independent clone of the template or a linked
      clone that shares storage with the template.
  EOT
  type        = bool
  default     = true
}

variable "clone_retries" {
  description = <<EOT
    Number of times to retry the clone operation if it fails (e.g., due to
    temporary Proxmox API or storage issues). Defaults to 3.
  EOT
  type        = number
  default     = 3

  validation {
    condition     = var.clone_retries >= 0
    error_message = "clone_retries must be a non-negative integer."
  }
}


###############################################################################
## Bios and hardware variables
###############################################################################
variable "bios" {
  description = <<EOT
    BIOS type for the VM. Use `seabios` for legacy BIOS or `ovmf` for UEFI.
    When null (default), inherits the BIOS setting from the template during clone.
    Set explicitly to override the template's BIOS configuration.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.bios == null || contains(["seabios", "ovmf"], lower(trimspace(var.bios)))
    error_message = "Invalid BIOS setting. Valid options: 'seabios' or 'ovmf'."
  }
}

variable "machine_type" {
  description = <<EOT
    Hardware layout for the VM. Valid options are `q35` (modern chipset) or
    `pc` (legacy chipset). When null (default), inherits the machine type from
    the template during clone. Set explicitly to override the template's machine type.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.machine_type == null || contains(["q35", "pc"], lower(trimspace(var.machine_type)))
    error_message = "Unknown machine_type. Valid options: 'q35' or 'pc'."
  }
}

variable "tablet" {
  description = <<EOT
    Enable tablet device for improved pointer accuracy in graphical environments.
    If set (not null), this value will overwrite the tablet setting inherited from
    the template.
  EOT
  type        = bool
  default     = null
}


###############################################################################
## CPU and memory variables
###############################################################################
variable "override_cpu" {
  description = <<EOT
    Whether to override the CPU configuration inherited from the template.
    If `true`, the `vcpu` and `vcpu_type` values will be applied to the clone.
    If `false`, the clone will retain the CPU settings from the template.
  EOT
  type        = bool
  default     = false
}

variable "cores" {
  description = "Number of virtual CPU cores assigned to the VM."
  type        = number
  default     = 1

  validation {
    condition     = var.cores >= 1
    error_message = "cores must be at least 1."
  }
}

variable "vcpu_type" {
  description = "CPU type for the VM. Use `host` to match the host CPU or specify a model."
  type        = string
  default     = "host"
}

variable "override_memory" {
  description = <<EOT
    Whether to override the memory configuration inherited from the template.
    If `true`, the `memory` (and optionally `memory_floating`) values will be
    applied to the clone. If `false`, the clone will retain the memory settings
    from the template.
  EOT
  type        = bool
  default     = false
}

variable "memory" {
  description = "Amount of memory (in MiB) allocated to the VM. Default is 1024 MiB."
  type        = number
  default     = 1024

  validation {
    condition     = var.memory >= 256
    error_message = "memory must be at least 256 MiB."
  }
}

variable "memory_floating" {
  description = <<EOT
    Minimum memory size (in MiB) for memory ballooning. Enables dynamic memory
    allocation if set lower than `memory`. If not set, defaults to the value of `memory`.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.memory_floating == null || var.memory_floating <= var.memory
    error_message = "memory_floating must be less than or equal to memory."
  }
}


###############################################################################
## VGA/display variables
###############################################################################
variable "override_vga" {
  description = <<EOT
    Whether to override the VGA configuration inherited from the template.
    If `true`, the `display_type` and `display_memory` values will be applied
    to the clone. If `false`, the clone will retain the display settings
    from the template.
  EOT
  type        = bool
  default     = false
}

variable "display_type" {
  description = <<EOT
    Virtual display adapter type to present to the guest. Supported values:

      - std        : Standard VGA (default)
      - cirrus     : Cirrus Logic GD5446 (legacy)
      - vmware     : VMware-compatible adapter
      - qxl|qxl2|qxl3|qxl4 : QXL (paravirtualized; commonly used with SPICE)
      - virtio     : Virtio VGA (modern, 2D); pairs well with virtio GPU stacks
      - virtio-gl  : Virtio + VirGL (3D acceleration with a GL-capable display)
      - serial0|serial1|serial2|serial3 : Serial text console (no framebuffer)
      - none       : No display device (headless)

    Defaults to `std`.
  EOT
  type        = string
  default     = "std"

  validation {
    condition = contains(
      [
        "std", "cirrus", "vmware",
        "qxl", "qxl2", "qxl3", "qxl4",
        "virtio", "virtio-gl",
        "serial0", "serial1", "serial2", "serial3",
        "none"
      ],
      lower(trimspace(var.display_type))
    )
    error_message = "Invalid display_type. Allowed: std, cirrus, vmware, qxl, qxl2, qxl3, qxl4, virtio, virtio-gl, serial0..serial3, none."
  }
}

variable "display_memory" {
  description = <<EOT
    Video memory size (in MB) for the VM display adapter. Must be between
    4 and 512 MB. Note: This setting has no effect when using a serial display
    (serial0..serial3). Defaults to 16 MB.
  EOT
  type        = number
  default     = 16

  validation {
    condition     = var.display_memory >= 4 && var.display_memory <= 512
    error_message = "display_memory must be an integer between 4 and 512 MB."
  }
}


###############################################################################
## Image variables
###############################################################################
variable "agent_override" {
  description = <<EOT
    Whether to override the QEMU Guest Agent setting inherited from the template.
    If `true`, the `qemu_guest_agent` value will be applied to the clone.
    If `false`, the clone will retain the QEMU Guest Agent setting from the template.
  EOT
  type        = bool
  default     = false
}

variable "qemu_guest_agent" {
  description = <<EOT
    Enable the QEMU Guest Agent for better integration with the Proxmox host.
    This allows features like IP address reporting, graceful shutdown, and
    disk trimming. The guest OS must have the qemu-guest-agent package installed.
  EOT
  type        = bool
  default     = true
}


###############################################################################
## Disk variables
###############################################################################
variable "efi_disk_override" {
  description = <<EOT
    Whether to override the EFI disk configuration inherited from the template.
    If `true`, an EFI disk will be created for the clone, overriding the template's
    setting. Ensure the VM's BIOS is set to `ovmf` for UEFI boot to function.
    If `false`, the clone will retain the EFI disk configuration from the template.
  EOT
  type        = bool
  default     = false
}

variable "efi_datastore" {
  description = <<EOT
    Storage location for the EFI disk (used with UEFI boot). If not set,
    defaults to the primary disk datastore.
  EOT
  type        = string
  default     = null
}

variable "efi_disk_format" {
  description = "Storage format for the EFI disk. Common values: `raw`, `qcow2`."
  type        = string
  default     = "raw"
}

variable "efi_disk_type" {
  description = "OVMF firmware version for the EFI disk. Common values: `4m`, `fd`."
  type        = string
  default     = "4m"
}

variable "efi_disk_pre_enrolled_keys" {
  description = "Enable pre-enrolled secure boot keys for the EFI disk."
  type        = bool
  default     = true
}


###############################################################################
## USB device passthrough
###############################################################################
variable "usb_devices" {
  description = <<EOT
    USB devices to pass through to the VM. Use 'mapping' (Proxmox resource
    mapping name) or 'host' (vendorid:productid format, e.g., "051d:0003").
  EOT
  type = list(object({
    host    = optional(string, null)
    mapping = optional(string, null)
    usb3    = optional(bool, false)
  }))
  default = []
}


###############################################################################
## Block device variables for additional disks
###############################################################################
variable "disks" {
  description = <<EOT
    A list of additional disk configurations to attach to the VM. These disks
    are provisioned in addition to the primary disk defined in the template.
    Each object in the list supports the following attributes:

      - disk_datastore : Storage location for the disk (default: "local-lvm").
      - disk_interface : Device interface name (e.g., "scsi0", "virtio0").
      - disk_size      : Disk size in GiB (default: 8).
      - disk_format    : Disk format (e.g., "raw", "qcow2"; default: "raw").
      - disk_cache     : Cache mode (e.g., "writeback", "none"; default: "writeback").
      - disk_iothread  : Enable IO threading (default: false).
      - disk_ssd       : Enable SSD emulation (default: true).
      - disk_discard   : TRIM/Discard setting ("on", "ignore", "unmap"; default: "on").

    Use this variable to add extra storage volumes for data, logs, or application
    needs beyond the base disk provided by the template.
  EOT
  type = list(object({
    disk_datastore = optional(string, "local-lvm")
    disk_interface = optional(string, "scsi0")
    disk_size      = optional(number, 8)
    disk_format    = optional(string, "raw")
    disk_cache     = optional(string, "writeback")
    disk_iothread  = optional(bool, false)
    disk_ssd       = optional(bool, true)
    disk_discard   = optional(string, "on")
  }))

  default = []

  validation {
    condition = alltrue([
      for d in var.disks : length(trimspace(d.disk_datastore)) > 0 && length(trimspace(d.disk_interface)) > 0
    ])
    error_message = "disk_datastore and disk_interface must be non-empty strings."
  }

  validation {
    condition = alltrue([
      for d in var.disks : d.disk_size >= 1
    ])
    error_message = "disk_size must be at least 1 GiB."
  }

  validation {
    condition = alltrue([
      for d in var.disks : contains(["raw", "qcow2"], lower(d.disk_format))
    ])
    error_message = "disk_format must be either 'raw' or 'qcow2'."
  }

  validation {
    condition = alltrue([
      for d in var.disks : contains(["writeback", "none", "directsync"], lower(d.disk_cache))
    ])
    error_message = "disk_cache must be one of: writeback, none, directsync."
  }

  validation {
    condition = alltrue([
      for d in var.disks : contains(["on", "ignore", "unmap"], lower(d.disk_discard))
    ])
    error_message = "disk_discard must be one of: on, ignore, unmap."
  }
}


###############################################################################
## Network variables
###############################################################################
variable "network_interfaces" {
  description = <<EOT
    A list of additional network interface configurations to attach to the VM.
    These NICs are provisioned in addition to the primary NIC created in the
    template. Each object supports:

      - vnic_model  : Network adapter model. Supported values: `virtio` (recommended),
                      `e1000`, `e1000e`, `rtl8139`, `vmxnet3`. Defaults to `virtio`.
      - vnic_bridge : Bridge to attach the adapter to (default: `vmbr0`).
      - vlan_tag    : Optional VLAN tag for the adapter (null means no VLAN).
      - mac_address : Static MAC address for consistent DHCP IP assignment.
                      If null, a MAC is auto-generated using the format:
                      "02:01:XX:XX:XX:YY" where XX:XX:XX is the VM_ID (3 bytes)
                      and YY is the interface index (0, 1, 2, ...).

    Use this variable to add extra network interfaces for management, storage,
    or application needs beyond the base NIC provided by the template.
  EOT

  type = list(object({
    vnic_model  = optional(string, "virtio")
    vnic_bridge = optional(string, "vmbr0")
    vlan_tag    = optional(number, null)
    mac_address = optional(string, null)
  }))

  default = [{
    vnic_model  = "virtio"
    vnic_bridge = "vmbr0"
    vlan_tag    = null
    mac_address = null
  }]

  validation {
    condition = alltrue([
      for nic in var.network_interfaces : contains(["virtio", "e1000", "e1000e", "rtl8139", "vmxnet3"], lower(trimspace(nic.vnic_model)))
    ])
    error_message = "vnic_model must be one of: virtio, e1000, e1000e, rtl8139, vmxnet3."
  }

  validation {
    condition = alltrue([
      for nic in var.network_interfaces : length(trimspace(nic.vnic_bridge)) > 0
    ])
    error_message = "vnic_bridge must be a non-empty string."
  }

  validation {
    condition = alltrue([
      for nic in var.network_interfaces : nic.vlan_tag == null || (nic.vlan_tag >= 1 && nic.vlan_tag <= 4094)
    ])
    error_message = "vlan_tag must be null or an integer between 1 and 4094."
  }

  validation {
    condition = alltrue([
      for nic in var.network_interfaces : nic.mac_address == null || can(regex("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$", nic.mac_address))
    ])
    error_message = "mac_address must be null or a valid MAC address format (xx:xx:xx:xx:xx:xx)."
  }
}


###############################################################################
## Cloud-init variables
###############################################################################
variable "cloud-init_override" {
  description = <<EOT
    Whether to override the cloud-init configuration inherited from the template.
    If `true`, the cloud-init settings will be applied to the clone.
    If `false`, the clone will retain the cloud-init settings from the template.
  EOT
  type        = bool
  default     = false
}

variable "ci_datastore" {
  description = <<EOT
    Storage location for the cloud-init disk. If not set, defaults to the
    primary disk datastore.
  EOT
  type        = string
  default     = null
}

variable "ci_interface" {
  description = <<EOT
    Hardware interface used for cloud-init configuration (e.g., `ide2`, `scsi2`).
  EOT
  type        = string
  default     = "ide2"
}

variable "ci_datasource_type" {
  description = "Type of cloud-init datasource. Common value: `nocloud`."
  type        = string
  default     = "nocloud"
}

variable "ci_user_data" {
  description = <<EOT
    Optional path to a custom cloud-init `user-data` snippet file. This should
    reference a file generated via the `./modules/pve_cloud-init` module, such as
    `local:snippets/user-data.yaml`.
  EOT
  type        = string
  default     = null
}

variable "ci_vendor_data" {
  description = <<EOT
    Optional path to a custom cloud-init `vendor-data` snippet file. This should
    reference a file generated via the `./modules/pve_cloud-init` module, such as
    `local:snippets/vendor-data.yaml`.
  EOT
  type        = string
  default     = null
}

variable "ci_network_data" {
  description = <<EOT
    Optional path to a custom cloud-init `network-config` snippet file. This should
    reference a file generated via the `./modules/pve_cloud-init` module, such as
    `local:snippets/network-data.yaml`.
  EOT
  type        = string
  default     = null
}

variable "ci_meta_data" {
  description = <<EOT
    Optional path to a custom cloud-init `meta-data` snippet file. This should
    reference a file generated via the `./modules/pve_cloud-init` module, such as
    `local:snippets/meta-data.yaml`.
  EOT
  type        = string
  default     = null
}


###############################################################################
## Startup variables
###############################################################################
variable "wait_for_agent" {
  description = <<EOT
    Whether to wait for the QEMU guest agent to become available before
    considering the VM creation complete. Set to `false` for VMs where the
    agent is not yet installed (e.g., during OS installation). Defaults to `true`.

    When `true`, Terraform waits up to 15 minutes for the agent to respond.
    When `false`, Terraform only waits 5 seconds before continuing.
  EOT
  type        = bool
  default     = true
}

variable "protection" {
  description = "Enable protection against VM removal."
  type        = bool
  default     = true
}

variable "start_on_boot" {
  description = "Start VM on PVE boot."
  type        = bool
  default     = false
}

variable "start_on_create" {
  description = "Start VM after creation."
  type        = bool
  default     = true
}

variable "start_order" {
  description = "Start order, e.g. `1`."
  type        = number
  default     = 1

  validation {
    condition     = var.start_order >= 1
    error_message = "start_order must be at least 1."
  }
}

variable "start_delay" {
  description = "Startup delay in seconds, e.g. `30`."
  type        = number
  default     = null

  validation {
    condition     = var.start_delay == null || var.start_delay >= 0
    error_message = "start_delay must be a non-negative number of seconds."
  }
}

variable "shutdown_delay" {
  description = "Shutdown delay in seconds, e.g. `30`."
  type        = number
  default     = null

  validation {
    condition     = var.shutdown_delay == null || var.shutdown_delay >= 0
    error_message = "shutdown_delay must be a non-negative number of seconds."
  }
}
