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
}

variable "acme_directory" {
  description = "ACME directory URL. Defaults to Let's Encrypt production."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
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
  description = "Cloudflare API token for the DNS-01 challenge. Sensitive value; stored in state with the plugin data."
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
