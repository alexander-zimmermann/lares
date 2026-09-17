###############################################################################
## Jobs
###############################################################################
variable "verify" {
  description = <<EOT
    Map of job ID => verify job. `schedule` is a PBS calendar event; unset
    keeps the job without automatic runs. `ignore_verified` and
    `outdated_after` follow the PBS defaults when unset (skip verified
    snapshots, never recheck).
  EOT
  type = map(object({
    store           = string
    schedule        = optional(string)
    comment         = optional(string)
    ignore_verified = optional(bool)
    outdated_after  = optional(number)
  }))
  default = {}
}

variable "prune" {
  description = <<EOT
    Map of job ID => prune job. `keep` maps a retention window (`last`,
    `hourly`, `daily`, `weekly`, `monthly`, `yearly`) to the number of
    snapshots to keep; a window absent from the map is removed from the job.
  EOT
  type = map(object({
    store    = string
    schedule = string
    keep     = map(number)
    comment  = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for job in values(var.prune) : length(setsubtract(keys(job.keep), ["last", "hourly", "daily", "weekly", "monthly", "yearly"])) == 0
    ])
    error_message = "prune keep windows must be a subset of: last, hourly, daily, weekly, monthly, yearly."
  }

  validation {
    condition     = alltrue([for job in values(var.prune) : length(job.keep) > 0])
    error_message = "every prune job needs at least one keep window."
  }
}

variable "sync" {
  description = <<EOT
    Map of job ID => sync job pulling `remote_store` into `store` on this PBS
    (local sync, no remote). `remove_vanished` drops snapshots from `store`
    that the source no longer has.
  EOT
  type = map(object({
    store           = string
    remote_store    = string
    schedule        = string
    remove_vanished = optional(bool, false)
    comment         = optional(string)
  }))
  default = {}
}


###############################################################################
## SSH connection
###############################################################################
variable "ssh_hostname" {
  description = <<EOT
    Hostname or IP address of the PBS VM used for SSH access. This must be
    reachable from the system executing the configuration.
  EOT
  type        = string

  validation {
    condition     = length(var.ssh_hostname) > 0
    error_message = "ssh_hostname must be a non-empty string."
  }
}

variable "ssh_username" {
  description = <<EOT
    SSH username with passwordless sudo on the PBS VM. Defaults to `root`.
  EOT
  type        = string
  default     = "root"
}

variable "ssh_private_key" {
  description = <<EOT
    Path to the private key used for SSH authentication to the PBS VM.
    This key must allow access to the specified user and host. Sensitive value.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_port" {
  description = <<EOT
    SSH port used to connect to the PBS VM. Defaults to `22`.
  EOT
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535
    error_message = "ssh_port must be a valid port number between 1 and 65535."
  }
}
