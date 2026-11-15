###############################################################################
## General VM variables
###############################################################################
variable "node" {
  description = <<EOT
    Name of the Proxmox node where the VM template will be provisioned. This
    should match the node name as defined in your Proxmox cluster (e.g., `pve`).
  EOT
  type        = string

  validation {
    condition     = length(var.node) > 0
    error_message = "node must be a non-empty string."
  }
}

variable "name" {
  description = <<EOT
    Name of the VM template. Must be alphanumeric and may include dashes (`-`)
    and underscores (`_`). Underscores will be automatically replaced with dashes
    for DNS-compliant hostname. If not set, defaults to the Proxmox naming
    convention (e.g., `VM <VM_ID>`).
  EOT
  type        = string
  default     = null
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
    Optional description for the VM template. Useful for documentation and
    identifying the purpose of the template.
  EOT
  type        = string
  default     = null
}

variable "tags" {
  description = <<EOT
    List of UI tags for categorizing the template in Proxmox. Null to omit.
    Each tag must be a non-empty string.
  EOT
  type        = list(string)
  default     = null

  validation {
    condition     = var.tags == null || alltrue([for t in var.tags : length(trimspace(t)) > 0])
    error_message = "Each tag must be a non-empty string."
  }
}


###############################################################################
## Bios and hardware variables
###############################################################################
variable "bios" {
  description = <<EOT
    BIOS type for the VM. Use `seabios` for legacy BIOS or `ovmf` for UEFI.
    Setting to `ovmf` will automatically create an EFI disk.
  EOT
  type        = string
  default     = "seabios"

  validation {
    condition     = contains(["seabios", "ovmf"], var.bios)
    error_message = "Invalid BIOS setting: ${var.bios}. Valid options: 'seabios' or 'ovmf'."
  }
}

variable "machine_type" {
  description = <<EOT
    Hardware layout for the VM. Valid options are `q35` (modern chipset) or
    `pc` (legacy chipset). If null, Proxmox will use the default.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.machine_type == null || contains(["q35", "pc"], var.machine_type)
    error_message = "machine_type must be null, 'q35', or 'pc'."
  }
}

variable "tablet" {
  description = <<EOT
    Enable tablet device for improved pointer accuracy in graphical environments.
  EOT
  type        = bool
  default     = false
}

variable "boot_order" {
  description = <<EOT
    Custom boot order for the VM. List of strings (e.g., ["scsi0", "ide2", "net0"]).
    If null, the module uses a default UEFI/legacy logic.
  EOT
  type        = list(string)
  default     = null
}

variable "cdrom_interface" {
  description = <<EOT
    Hardware interface used for the CD-ROM drive (e.g., `ide2`, `scsi2`).
    Defaults to `ide2`.
  EOT
  type        = string
  default     = "ide2"
}


###############################################################################
## CPU and memory variables
###############################################################################
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

variable "memory" {
  description = "Amount of memory (in MiB) allocated to the VM. Default is 1024 MiB."
  type        = number
  default     = 1024

  validation {
    condition     = var.memory >= 128
    error_message = "memory must be at least 128 MiB."
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
variable "display_type" {
  description = <<EOT
    Virtual display adapter type to present to the guest.

    Supported values:
      - std        : Standard VGA adapter
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
        "std", "cirrus", "vmware", "qxl", "qxl2", "qxl3", "qxl4", "virtio", "virtio-gl",
        "serial0", "serial1", "serial2", "serial3", "none"
      ],
      lower(trimspace(var.display_type))
    )
    error_message = <<EOT
      Invalid display_type. Allowed: std, cirrus, vmware, qxl, qxl2, qxl3,
      qxl4, virtio, virtio-gl, serial0..serial3, none.
    EOT
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
variable "image_id" {
  description = <<EOT
    Optional identifier of a disk image to import into the VM. If provided, the
    VM disk will be created from this image (e.g., a cloud-init base image
    downloaded via the `pve_image` module). If null, a blank disk of the
    specified size will be created instead.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.image_id == null || length(trimspace(var.image_id)) > 0
    error_message = "image_id must be null or a non-empty string when provided."
  }
}

variable "image_type" {
  description = <<EOT
    Content type of the image behind image_id: `import` becomes the boot disk,
    `iso` a CD-ROM next to a blank disk, null leaves a blank disk only. It is
    known at plan time even when image_id is not (e.g. after an image bump),
    so the disk layout never changes between plan and apply.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.image_type == null || contains(["import", "iso"], var.image_type)
    error_message = "image_type must be null, import or iso."
  }
}

variable "os_type" {
  description = <<EOT
    Guest operating system type for the VM. This influences default hardware
    settings and optimizations in Proxmox (e.g., display, drivers, ballooning).

    Common values:
      - `l26`     : Linux (kernel 2.6 or later, most modern Linux distros)
      - `l24`     : Linux (kernel 2.4)
      - `win11`   : Microsoft Windows 11 / Server 2022+
      - `win10`   : Microsoft Windows 10 / Server 2016/2019
      - `win8`    : Microsoft Windows 8.x / Server 2012/2012R2
      - `win7`    : Microsoft Windows 7 / Server 2008R2
      - `w2k8`    : Microsoft Windows Vista / Server 2008
      - `w2k3`    : Microsoft Windows 2003
      - `w2k`     : Microsoft Windows 2000
      - `wxp`     : Microsoft Windows XP
      - `wvista`  : Microsoft Windows Vista (legacy alias)
      - `solaris` : Solaris-based OS
      - `other`   : Other/unknown OS

    Defaults to `other`.
  EOT
  type        = string
  default     = "other"

  validation {
    condition = (
      var.os_type == null ||
      contains([
        "other", "wxp", "w2k", "w2k3", "w2k8", "wvista",
        "win7", "win8", "win10", "win11",
        "l24", "l26", "solaris"
      ], lower(trimspace(var.os_type)))
    )
    error_message = <<EOM
      Invalid os_type. Allowed values:
      other, wxp, w2k, w2k3, w2k8, wvista, win7, win8, win10, win11, l24, l26, solaris.
    EOM
  }
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
## EFI disk variables
###############################################################################
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

variable "secure_boot" {
  description = <<EOT
    Enable UEFI Secure Boot for the VM. Requires UEFI firmware (bios = "ovmf")
    and is mandatory for Windows 11. When enabled, only signed bootloaders
    and kernels can be executed.
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.secure_boot || var.bios == "ovmf"
    error_message = "secure_boot can only be enabled when bios is set to 'ovmf' (UEFI firmware)."
  }
}

###############################################################################
## TPM and Security variables (Windows 11 specific)
###############################################################################
variable "enable_tpm" {
  description = <<EOT
    Enable Trusted Platform Module (TPM) 2.0 for the VM. Required for Windows 11
    and other modern operating systems that require TPM for boot and security.
    Only available with UEFI firmware (bios = "ovmf").
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_tpm || var.bios == "ovmf"
    error_message = "enable_tpm can only be enabled when bios is set to 'ovmf' (UEFI firmware)."
  }
}

variable "tpm_datastore" {
  description = <<EOT
    Storage location for the TPM state disk. If not set, defaults to the
    primary disk datastore. Only used when enable_tpm = true.
  EOT
  type        = string
  default     = null
}

variable "tpm_version" {
  description = <<EOT
    TPM version to emulate. Currently only "v2.0" is supported by Proxmox.
    Only used when enable_tpm = true.
  EOT
  type        = string
  default     = "v2.0"

  validation {
    condition     = contains(["v2.0"], var.tpm_version)
    error_message = "tpm_version must be 'v2.0' (currently the only supported version)."
  }
}


###############################################################################
## Block device variables
###############################################################################
variable "disk_datastore" {
  description = <<EOT
    Storage location for the primary VM disk. Must reference a valid Proxmox
    datastore ID (e.g., "local-lvm", "local-zfs"). This disk is created as part
    of the template and serves as the root volume for the operating system.
  EOT
  type        = string
  default     = "local-lvm"

  validation {
    condition     = length(trimspace(var.disk_datastore)) > 0
    error_message = <<EOT
      disk_datastore must be a non-empty string representing a valid Proxmox
      datastore.
    EOT
  }
}

variable "disk_interface" {
  description = <<EOT
    Interface name for the primary VM disk (e.g., "scsi0", "virtio0").
    Determines how the disk is attached to the VM. Common choices:
    - scsi0 (recommended for flexibility)
    - virtio0 (high performance)
  EOT
  type        = string
  default     = "scsi0"

  validation {
    condition     = length(trimspace(var.disk_interface)) > 0
    error_message = "disk_interface must be a non-empty string (e.g., scsi0, virtio0)."
  }
}

variable "disk_size" {
  description = <<EOT
    Size of the primary VM disk in GiB. Must be at least 1 GiB. This disk is
    created during template provisioning and typically holds the OS.
  EOT
  type        = number
  default     = 8

  validation {
    condition     = var.disk_size >= 1
    error_message = "disk_size must be at least 1 GiB."
  }
}

variable "disk_format" {
  description = <<EOT
    Format of the primary VM disk. Supported values:
    - raw   : Unstructured disk image (fast, less flexible)
    - qcow2 : QEMU Copy-On-Write (supports snapshots)
  EOT
  type        = string
  default     = "raw"

  validation {
    condition     = contains(["raw", "qcow2"], lower(trimspace(var.disk_format)))
    error_message = "disk_format must be either 'raw' or 'qcow2'."
  }
}

variable "disk_cache" {
  description = <<EOT
    Disk cache mode for the primary disk. Common values:
    - writeback    : Best performance, risk on power loss
    - none         : No caching
    - directsync   : Safe but slower
  EOT
  type        = string
  default     = "writeback"

  validation {
    condition     = contains(["writeback", "none", "directsync"], lower(trimspace(var.disk_cache)))
    error_message = "disk_cache must be one of: writeback, none, directsync."
  }
}

variable "disk_iothread" {
  description = <<EOT
    Enable IO threading for the primary disk device. Recommended for virtio
    disks to improve performance under heavy IO.
  EOT
  type        = bool
  default     = false
}

variable "disk_ssd" {
  description = <<EOT
    Enable SSD emulation for the primary disk device. Improves guest OS
    optimizations for SSD-like behavior.
  EOT
  type        = bool
  default     = true
}

variable "disk_discard" {
  description = <<EOT
    Enable TRIM/Discard support for the primary disk. Supported values:
    - on      : Enable TRIM
    - ignore  : Disable TRIM
    - unmap   : Use UNMAP for thin-provisioned storage
  EOT
  type        = string
  default     = "on"

  validation {
    condition     = contains(["on", "ignore", "unmap"], lower(trimspace(var.disk_discard)))
    error_message = "disk_discard must be one of: on, ignore, unmap."
  }
}


###############################################################################
## Network variables
###############################################################################
variable "vnic_model" {
  description = <<EOT
    Optional virtual NIC model to use for the network interface. Models exposed
    in Proxmox include: `virtio` (recommended), `e1000`, `e1000e`, `rtl8139`,
    and `vmxnet3`. Defaults to `virtio`.
  EOT
  type        = string
  default     = "virtio"

  validation {
    condition = contains(
      ["virtio", "e1000", "e1000e", "rtl8139", "vmxnet3"],
      lower(trimspace(var.vnic_model))
    )
    error_message = "vnic_model must be one of: virtio, e1000, e1000e, rtl8139, vmxnet3."
  }
}

variable "vnic_bridge" {
  description = <<EOT
    Specifies the bridge to attach (e.g., `vmbr0`). Use an empty string for a
    NIC without a bridge (user-mode NAT 10.0.2.0/24), or null to omit the NIC entirely.
  EOT
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = <<EOT
    Optional VLAN tag (1..4094). If null, no VLAN tag is applied. VLAN
    tagging requires a NIC attached to a bridge (`vnic_bridge` to be set)
  EOT
  type        = number
  default     = null

  validation {
    condition = (
      var.vlan_tag == null ||
      (
        var.vlan_tag >= 1 &&
        var.vlan_tag <= 4094 &&
        length(trimspace(coalesce(var.vnic_bridge, ""))) > 0
      )
    )
    error_message = <<EOT
      vlan_tag must be null or an integer in the range 1..4094, and requires
      vnic_bridge to be set (non-empty).
    EOT
  }
}


###############################################################################
## Cloud-init variables
###############################################################################
variable "enable_cloud_init" {
  description = <<EOT
    Enable Cloud-Init support for the VM. This allows automated configuration
    of networking, SSH keys, and package installation during first boot.
    Required if qemu_guest_agent is enabled to ensure the agent package is installed.
  EOT
  type        = bool
  default     = true
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
  nullable    = false
  default     = "ide0"
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
