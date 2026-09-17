###############################################################################
## Realm
###############################################################################
variable "realm" {
  description = <<EOT
    Identifier of the realm as it appears in the PBS login dialog and in user
    IDs (e.g. `alice@authentik`).
  EOT
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9._-]+$", var.realm))
    error_message = "realm must start with a letter and contain only letters, digits, '.', '-' and '_'."
  }
}

variable "issuer_url" {
  description = <<EOT
    OpenID Connect issuer URL. PBS resolves the provider endpoints through
    OpenID Connect Discovery (`<issuer_url>/.well-known/openid-configuration`).
  EOT
  type        = string
}

variable "comment" {
  description = "Free-form comment attached to the realm and its mapped users."
  type        = string
  default     = "Managed by OpenTofu"
}

variable "default" {
  description = "Pre-select this realm in the PBS login dialog. Only one realm can be the default."
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
  description = <<EOT
    OpenID Connect client secret. Sensitive value; the provider keeps it in
    state, so give the PBS client its own secret at the identity provider.
  EOT
  type        = string
  sensitive   = true
}

variable "scopes" {
  description = "Space-separated OpenID scopes to request. PBS default is `email profile`; `openid` is always added."
  type        = string
  default     = null
}


###############################################################################
## User mapping
###############################################################################
variable "username_claim" {
  description = <<EOT
    Claim that becomes the local part of the PBS user ID. `username` maps to
    `preferred_username`, `subject` to `sub`; any other value is used verbatim.
    PBS default is `sub`. Changing it replaces the realm.
  EOT
  type        = string
  default     = null
}

variable "auto_create" {
  description = <<EOT
    Create the PBS user on first login. PBS default is false, which limits
    logins to the users declared in `users`.
  EOT
  type        = bool
  default     = null
}

variable "users" {
  description = <<EOT
    Map of login name => ACL. Each entry creates the PBS user `<name>@<realm>`
    and binds `role_id` to it at `path`. PBS has no groups, so every identity
    that may log in through the realm is listed here.
  EOT
  type = map(object({
    role_id   = string
    path      = string
    propagate = optional(bool, true)
  }))
  default = {}
}
