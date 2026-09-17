###############################################################################
## ACME account
###############################################################################
variable "account_name" {
  description = "Name of the ACME account on the PBS. Defaults to `letsencrypt-prod`."
  type        = string
  default     = "letsencrypt-prod"

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", var.account_name))
    error_message = "account_name must start with a letter, digit or '_' and contain only letters, digits, '.', '-' and '_'."
  }
}

variable "contact_email" {
  description = "Email address registered with the ACME account (expiry notices)."
  type        = string

  validation {
    condition     = can(regex("^[^'[:space:]]+@[^'[:space:]]+$", var.contact_email))
    error_message = "contact_email must be an address without whitespace or quotes."
  }
}

variable "acme_directory" {
  description = "ACME directory URL. Defaults to Let's Encrypt production."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"

  validation {
    condition     = !strcontains(var.acme_directory, "'")
    error_message = "acme_directory must not contain a single quote."
  }
}


###############################################################################
## DNS plugin (Cloudflare)
###############################################################################
variable "dns_plugin_id" {
  description = "Identifier of the ACME DNS plugin on the PBS. Defaults to `cloudflare`."
  type        = string
  default     = "cloudflare"

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]*$", var.dns_plugin_id))
    error_message = "dns_plugin_id must start with a letter, digit or '_' and contain only letters, digits, '.', '-' and '_'."
  }
}

variable "dns_api" {
  description = "acme.sh DNS API the plugin uses. `cf` for Cloudflare."
  type        = string
  default     = "cf"

  validation {
    condition     = can(regex("^[a-z0-9_]+$", var.dns_api))
    error_message = "dns_api must be a lowercase acme.sh API name."
  }
}

variable "cf_token" {
  description = "Cloudflare API token for the DNS-01 challenge. Sensitive value; reaches the PBS on stdin, never in state."
  type        = string
  sensitive   = true
}

variable "cf_zone_id" {
  description = "Cloudflare Zone ID of the domain. Optional."
  type        = string
  default     = null
}

variable "cf_account_id" {
  description = "Cloudflare Account ID. Optional."
  type        = string
  default     = null
}


###############################################################################
## Certificate
###############################################################################
variable "primary_domain" {
  description = "Primary name on the certificate (the PBS host name)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.primary_domain))
    error_message = "primary_domain must be a lowercase host name."
  }
}

variable "san_domains" {
  description = "Additional names on the certificate. PBS takes at most five names in total."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.san_domains) <= 4 && alltrue([for d in var.san_domains : can(regex("^[a-z0-9.-]+$", d))])
    error_message = "san_domains must be lowercase host names, at most four."
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
