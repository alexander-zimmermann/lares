###############################################################################
## ACME account
###############################################################################
variable "account_name" {
  description = <<EOT
    Name of the ACME account used for certificate issuance. This is a logical
    identifier within the Proxmox cluster and should be unique per environment.
    Defaults to `letsencrypt-prod`.
  EOT
  type        = string
  default     = "letsencrypt-prod"
}

variable "contact_email" {
  description = <<EOT
    Email address associated with the ACME account. This is used for important
    notifications such as certificate expiry and account status.
  EOT
  type        = string
}

variable "acme_directory" {
  description = <<EOT
    ACME directory endpoint URL. This defines the certificate authority's API
    used for registration and certificate issuance. Defaults to Let's Encrypt's
    production endpoint.
  EOT
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "acme_tos_url" {
  description = <<EOT
    URL to the Terms of Service for the ACME provider. This must be accepted
    during account registration. Defaults to Let's Encrypt's latest TOS.
  EOT
  type        = string
  default     = "https://letsencrypt.org/documents/LE-SA-v1.3-September-21-2022.pdf"
}

variable "acme_eab_kid" {
  description = <<EOT
    External Account Binding (EAB) Key ID. Optional and only required for ACME
    providers that enforce EAB (e.g., some enterprise CAs).
  EOT
  type        = string
  default     = null
}

variable "acme_eab_hmac_key" {
  description = <<EOT
    External Account Binding (EAB) HMAC key. Optional and only required when
    `acme_eab_kid` is set. Sensitive value.
  EOT
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.acme_eab_kid == null || (var.acme_eab_hmac_key != null && length(var.acme_eab_hmac_key) > 0)
    error_message = "acme_eab_hmac_key must be set if acme_eab_kid is provided."
  }
}


###############################################################################
## DNS plugin defaults (Cloudflare)
###############################################################################
variable "dns_plugin_id" {
  description = <<EOT
    Identifier for the ACME DNS plugin used to perform DNS-01 challenges.
    Defaults to `cloudflare`.
  EOT
  type        = string
  default     = "cloudflare"
}

variable "dns_api" {
  description = <<EOT
    Short identifier for the DNS API provider. For Cloudflare, this is typically `cf`.
  EOT
  type        = string
  default     = "cf"
}

variable "dns_plugin_data" {
  description = <<EOT
    Raw key-value map containing credentials and configuration for the DNS plugin.
    This is passed directly to the ACME client. Sensitive values such as API tokens
    should be included here.
  EOT
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "dns_plugin_disable" {
  description = <<EOT
    Flag to disable the DNS plugin entirely. Useful for testing or when using
    alternative challenge methods.
  EOT
  type        = bool
  default     = false
}

variable "dns_plugin_validation_delay" {
  description = <<EOT
    Number of seconds to wait after creating DNS challenge records before
    proceeding with validation. Useful for DNS propagation delays.
  EOT
  type        = number
  default     = 0
}

## Cloudflare convenience variables
variable "cf_token" {
  description = <<EOT
    Cloudflare API token used for DNS management. This is required for DNS-01
    challenge validation when using Cloudflare. Sensitive value.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "cf_zone_id" {
  description = <<EOT
    Cloudflare Zone ID for the domain being validated. This identifies the DNS
    zone where challenge records will be created.
  EOT
  type        = string
  default     = null
}

variable "cf_account_id" {
  description = <<EOT
    Cloudflare Account ID. Optional and only required for certain API operations.
  EOT
  type        = string
  default     = null
}


###############################################################################
## Certificate issuing
###############################################################################
variable "primary_domain" {
  description = <<EOT
    Primary domain name for the certificate. This is the main identifier
    for the cluster node.
  EOT
  type        = string

  validation {
    condition     = length(var.primary_domain) > 0
    error_message = "primary_domain must not be empty."
  }
}

variable "san_domains" {
  description = <<EOT
    List of Subject Alternative Names (SANs) to include in the certificate.
    Optional.
  EOT
  type        = list(string)
  default     = []
}

variable "ssh_hostname" {
  description = <<EOT
    Hostname or IP address of the Proxmox node where the certificate will be
    installed. Must be reachable via SSH.
  EOT
  type        = string
}

variable "ssh_username" {
  description = <<EOT
    SSH username with root privileges on the target node. Defaults to `root`.
  EOT
  type        = string
  default     = "root"
}

variable "ssh_private_key" {
  description = <<EOT
    Path to the private key used for SSH authentication to the Proxmox node.
    This key must have access to the specified user and host. Sensitive value.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_port" {
  description = <<EOT
    SSH port used to connect to the Proxmox node. Defaults to `22`.
  EOT
  type        = number
  default     = 22
}
