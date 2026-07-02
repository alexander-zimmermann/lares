###############################################################################
## Backup job identity
###############################################################################
variable "job_id" {
  description = "Unique identifier for the backup job as it appears in Proxmox (e.g. 'daily-backup')."
  type        = string

  validation {
    condition     = length(var.job_id) > 0
    error_message = "job_id must be a non-empty string."
  }
}

variable "schedule" {
  description = <<EOT
    Backup schedule in systemd calendar event format (e.g. '*-*-* 04:00' for daily at 4 AM).
    See: https://pve.proxmox.com/pve-docs/pve-admin-guide.html#chapter_calendar_events
  EOT
  type        = string

  validation {
    condition     = length(var.schedule) > 0
    error_message = "schedule must be a non-empty string."
  }
}


###############################################################################
## Backup target
###############################################################################
variable "storage" {
  description = "Storage ID where backups will be stored. Must reference a PBS storage configured in Proxmox."
  type        = string

  validation {
    condition     = length(var.storage) > 0
    error_message = "storage must be a non-empty string."
  }
}

variable "vmids" {
  description = "List of VM/container IDs to include in the backup job. Must contain at least one ID."
  type        = list(number)

  validation {
    condition     = length(var.vmids) > 0
    error_message = "vmids must contain at least one VM/container ID."
  }

  validation {
    condition     = alltrue([for id in var.vmids : id > 0])
    error_message = "All VM IDs must be positive integers."
  }
}


###############################################################################
## Backup options
###############################################################################
variable "mode" {
  description = <<EOT
    Backup mode. One of:
      - snapshot: Live backup without downtime (requires QEMU guest agent or freeze support).
      - suspend:  Suspend the VM during backup.
      - stop:     Shut down the VM before backup and restart afterwards.
    Defaults to `snapshot`.
  EOT
  type        = string
  default     = "snapshot"

  validation {
    condition     = contains(["snapshot", "suspend", "stop"], var.mode)
    error_message = "mode must be one of: snapshot, suspend, stop."
  }
}

variable "compress" {
  description = <<EOT
    Compression algorithm for backup data. One of:
      - 0 / 1: No compression / LZO (legacy aliases).
      - gzip:  Good compression ratio, slower.
      - lzo:   Fast compression, lower ratio.
      - zstd:  Best balance of speed and compression ratio (recommended).
    Defaults to `zstd`.
  EOT
  type        = string
  default     = "zstd"

  validation {
    condition     = contains(["0", "1", "gzip", "lzo", "zstd"], var.compress)
    error_message = "compress must be one of: 0, 1, gzip, lzo, zstd."
  }
}


###############################################################################
## Resource throttling (host CPU / IO impact) — all optional, null = PVE default
###############################################################################
variable "zstd" {
  description = <<EOT
    Number of threads zstd uses for compression. 0 (Proxmox default) uses half
    of the host's cores; set to 1 to cap compression to a single thread and keep
    the backup from spiking host CPU load. Null leaves the Proxmox default.
  EOT
  type        = number
  default     = null
}

variable "max_workers" {
  description = <<EOT
    Maximum number of parallel backup workers (Proxmox default 16). Lowering it
    reduces concurrent CPU/IO pressure on the host. Null leaves the default.
  EOT
  type        = number
  default     = null
}

variable "ionice" {
  description = <<EOT
    I/O priority (0-8) for the backup; in snapshot mode this applies to the
    compressor. 8 runs it in the idle I/O class. Null leaves the Proxmox default.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.ionice == null ? true : (var.ionice >= 0 && var.ionice <= 8)
    error_message = "ionice must be between 0 and 8."
  }
}

variable "bwlimit" {
  description = "Backup I/O bandwidth limit in KiB/s. Null leaves it unlimited (Proxmox default)."
  type        = number
  default     = null
}
