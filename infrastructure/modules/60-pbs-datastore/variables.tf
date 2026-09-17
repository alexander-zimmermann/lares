###############################################################################
## Datastore
###############################################################################
variable "name" {
  description = "Name of the datastore as it appears in PBS and in ACL paths (`/datastore/<name>`)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", var.name))
    error_message = "name must start with a letter, digit or '_' and contain only letters, digits, '.', '-' and '_'."
  }
}

variable "path" {
  description = "Absolute path of the datastore directory on the PBS VM."
  type        = string

  validation {
    condition     = startswith(var.path, "/")
    error_message = "path must be absolute."
  }
}

variable "comment" {
  description = "Free-form comment attached to the datastore."
  type        = string
  default     = null
}

variable "reuse_datastore" {
  description = <<EOT
    Adopt an existing chunk store at `path` instead of creating one. PBS then
    checks that the directory tree is owned by `backup:backup` with its own
    modes. Create-only; meant for a datastore whose data outlives the VM.
  EOT
  type        = bool
  default     = null
}


###############################################################################
## Maintenance
###############################################################################
variable "gc_schedule" {
  description = "Calendar event for garbage collection (e.g. `daily`). Unset leaves GC manual."
  type        = string
  default     = null
}

variable "verify_new" {
  description = "Verify new backups right after completion. PBS default is false."
  type        = bool
  default     = null
}

variable "notification_mode" {
  description = "`notification-system` or `legacy-sendmail`. Unset keeps the PBS default."
  type        = string
  default     = null

  validation {
    condition     = var.notification_mode == null || contains(["notification-system", "legacy-sendmail"], var.notification_mode)
    error_message = "notification_mode must be `notification-system` or `legacy-sendmail`."
  }
}

variable "tuning" {
  description = "Datastore tuning options in PBS property-string format (e.g. `chunk-order=none`)."
  type        = string
  default     = null
}
