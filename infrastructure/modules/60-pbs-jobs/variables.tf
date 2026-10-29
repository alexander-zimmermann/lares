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
}
