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

## IDs and stores follow the PBS ID rule; schedules go into a quoted shell
## line, so they may not carry a quote themselves
variable "prune" {
  description = <<EOT
    Map of job ID => prune job. `keep` maps a retention window (`last`,
    `hourly`, `daily`, `weekly`, `monthly`, `yearly`) to the number of
    snapshots to keep (at least 1); a window absent from the map is removed
    from the job.
  EOT
  type = map(object({
    store    = string
    schedule = string
    keep     = map(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for id, job in var.prune : can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", id)) && can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", job.store))
    ])
    error_message = "prune job IDs and stores must start with a letter, digit or '_' and contain only letters, digits, '.', '-' and '_'."
  }

  validation {
    condition     = alltrue([for job in values(var.prune) : !strcontains(job.schedule, "'")])
    error_message = "prune schedules must not contain a single quote."
  }

  validation {
    condition = alltrue([
      for job in values(var.prune) : length(setsubtract(keys(job.keep), ["last", "hourly", "daily", "weekly", "monthly", "yearly"])) == 0
    ])
    error_message = "prune keep windows must be a subset of: last, hourly, daily, weekly, monthly, yearly."
  }

  validation {
    condition     = alltrue([for job in values(var.prune) : length(job.keep) > 0 && alltrue([for n in values(job.keep) : n >= 1])])
    error_message = "every prune job needs at least one keep window, each keeping at least 1 snapshot."
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
  }))
  default = {}

  validation {
    condition = alltrue([
      for id, job in var.sync : alltrue([for s in [id, job.store, job.remote_store] : can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", s))])
    ])
    error_message = "sync job IDs and stores must start with a letter, digit or '_' and contain only letters, digits, '.', '-' and '_'."
  }

  validation {
    condition     = alltrue([for job in values(var.sync) : !strcontains(job.schedule, "'")])
    error_message = "sync schedules must not contain a single quote."
  }
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
