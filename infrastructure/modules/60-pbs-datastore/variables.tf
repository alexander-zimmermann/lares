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
  description = "Free-form comment attached to the datastore. Unset by default: the imported datastores carry none."
  type        = string
  default     = null
}

variable "reuse_datastore" {
  description = <<EOT
    Adopt an existing chunk store at `path` instead of creating one. PBS then
    checks that the directory tree is owned by `backup:backup` with its own
    modes and refuses an empty directory. Create-only; meant for a datastore
    whose data outlives the VM.
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
