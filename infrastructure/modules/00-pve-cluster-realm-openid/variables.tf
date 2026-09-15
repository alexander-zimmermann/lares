###############################################################################
## Realm
###############################################################################
variable "realm" {
  description = <<EOT
    Identifier of the realm as it appears in the PVE login dialog and in user
    IDs (e.g. `alice@authentik`). Also becomes the suffix of every mapped group.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9._-]+$", var.realm))
    error_message = "realm must start with a letter and contain only letters, digits, '.', '-' and '_'."
  }
}

variable "issuer_url" {
  description = <<EOT
    OpenID Connect issuer URL. PVE resolves the provider endpoints through
    OpenID Connect Discovery (`<issuer_url>/.well-known/openid-configuration`).
  EOT
  type        = string
}

variable "comment" {
  description = "Free-form comment attached to the realm and its mapped groups."
  type        = string
  default     = "Managed by OpenTofu"
}

variable "default" {
  description = "Pre-select this realm in the PVE login dialog. Only one realm can be the default."
  type        = bool
  default     = false
}


###############################################################################
## OIDC client
###############################################################################
variable "client_id" {
  description = "OpenID Connect client ID registered at the identity provider."
  type        = string
}

variable "client_key" {
  description = "OpenID Connect client secret. Sensitive value; sent write-only, never stored in state."
  type        = string
  sensitive   = true
}

variable "client_key_version" {
  description = <<EOT
    Rotation counter for `client_key`. Write-only values are invisible to the
    plan, so increment this whenever the secret changes to force a re-send.
  EOT
  type        = number
  default     = 1
}

variable "scopes" {
  description = "Space-separated OpenID scopes to request. PVE default is `email profile`; `openid` is always added."
  type        = string
  default     = null
}


###############################################################################
## User mapping
###############################################################################
variable "username_claim" {
  description = <<EOT
    Claim that becomes the local part of the PVE user ID. `username` maps to
    `preferred_username`, `subject` to `sub`; any other value is used verbatim.
    PVE default is `sub`.
  EOT
  type        = string
  default     = null
}

variable "autocreate" {
  description = "Create the PVE user on first login. PVE default is false."
  type        = bool
  default     = null
}


###############################################################################
## Group mapping
###############################################################################
variable "groups_claim" {
  description = "Claim carrying the user's group list. Unset disables group sync."
  type        = string
  default     = null
}

variable "groups_autocreate" {
  description = <<EOT
    Create PVE groups for every claim value on login. When false, PVE only
    assigns groups that already exist — i.e. the ones declared in `groups`.
    PVE default is false.
  EOT
  type        = bool
  default     = null
}

variable "groups_overwrite" {
  description = "Replace the user's PVE group memberships on every login instead of appending. PVE default is false."
  type        = bool
  default     = null
}

variable "groups" {
  description = <<EOT
    Map of claim group name => ACL. Each entry creates the PVE group
    `<name>-<realm>` and binds `role_id` to it at `path`.
  EOT
  type = map(object({
    role_id   = string
    path      = string
    propagate = optional(bool, true)
  }))
  default = {}
}
