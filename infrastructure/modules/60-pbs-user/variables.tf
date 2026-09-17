###############################################################################
## User identity and authentication
###############################################################################
variable "username" {
  description = "Local part of the user ID (e.g. `backup` for `backup@pbs`)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", var.username))
    error_message = "username must start with a letter, digit or '_' and contain only letters, digits, '.', '-' and '_'."
  }
}

variable "realm" {
  description = "Authentication realm of the user. Defaults to `pbs`."
  type        = string
  default     = "pbs"

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", var.realm))
    error_message = "realm must start with a letter, digit or '_' and contain only letters, digits, '.', '-' and '_'."
  }
}

variable "enabled" {
  description = "Whether the user can log in."
  type        = bool
  default     = true
}

variable "comment" {
  description = "Free-form comment attached to the user and its token. Unset by default: the imported users carry none."
  type        = string
  default     = null
}

variable "password" {
  description = <<EOT
    Password of the user, set over SSH. Null leaves the stored password
    untouched (token-only users need none). Sensitive value.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "password_version" {
  description = <<EOT
    Rotation counter for `password`. The value itself never reaches the plan
    or state, so increment this whenever it changes to force a re-send.
  EOT
  type        = number
  default     = 1
}


###############################################################################
## Role and permissions
###############################################################################
variable "role_id" {
  description = "PBS role bound to the user (and its token) at `path`, e.g. `Admin`, `Audit`, `DatastoreAdmin`."
  type        = string
}

variable "path" {
  description = "ACL path the role is bound at, e.g. `/` or `/datastore/<name>`."
  type        = string

  validation {
    condition     = startswith(var.path, "/")
    error_message = "path must start with '/'."
  }
}

variable "propagate" {
  description = "Whether the ACL propagates to child paths."
  type        = bool
  default     = true
}


###############################################################################
## Token configuration
###############################################################################
variable "create_token" {
  description = "Create an API token for the user, bound at `path` with `role_id` like the user."
  type        = bool
  default     = false
}

variable "token_name" {
  description = "Name of the token (`<user_id>!<token_name>`). Required when `create_token` is true."
  type        = string
  default     = null

  validation {
    condition     = !var.create_token || (var.token_name != null && length(var.token_name) > 0)
    error_message = "token_name must be set when create_token is true."
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
