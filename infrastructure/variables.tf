###############################################################################
## PVE cluster - API connection & auth
###############################################################################
variable "pve_cluster_token_id" {
  description = <<EOT
    Identifier of the Proxmox API token used for authentication. Must follow
    the format `username!tokenname`, where `username` includes the realm (e.g.,
    `admin@pam!mytoken`). Sensitive value.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^!]+![^!]+$", var.pve_cluster_token_id))
    error_message = "pve_cluster_token_id must follow the format 'username!tokenname'."
  }
}

variable "pve_cluster_token_secret" {
  description = <<EOT
    Secret value of the Proxmox API token. This is used together with
    `pve_cluster_token_id` to authenticate API requests. Sensitive value.
  EOT
  type        = string
  sensitive   = true
}

variable "pve_cluster_password" {
  description = <<EOT
    Password for API authentication when not using an API token. Required for
    operations that require full user privileges. Sensitive value.
  EOT
  type        = string
  sensitive   = true
}


###############################################################################
## PVE cluster - user configuration
###############################################################################
variable "pve_cluster_user_passwords" {
  description = <<EOT
    Map of username => password for PVE users defined in manifest/00-cluster/pve-cluster-users.yaml.
    This allows setting user passwords during provisioning. Sensitive value.
  EOT
  type        = map(string)
  sensitive   = true
}


###############################################################################
## PVE cluster - ACME configuration
###############################################################################
variable "pve_cluster_acme_cf_token" {
  description = <<EOT
    Cloudflare API token used for DNS management. This is required for DNS-01
    challenge validation when using Cloudflare. Sensitive value.
  EOT
  type        = string
  sensitive   = true
}

variable "pve_cluster_acme_cf_zone_id" {
  description = <<EOT
    Cloudflare Zone ID for the domain being validated. This identifies the DNS
    zone where challenge records will be created.
  EOT
  type        = string
  default     = null
}

variable "pve_cluster_acme_cf_account_id" {
  description = <<EOT
    Cloudflare Account ID. Optional and only required for certain API operations.
  EOT
  type        = string
  default     = null
}


###############################################################################
## PVE cluster - PBS storage configuration
###############################################################################
variable "pve_cluster_pbs_passwords" {
  description = <<EOT
    Map of PBS storage ID => password for the PBS backup user defined in
    manifest/00-cluster/pve-cluster-pbs-storage.yaml. Sensitive value.
  EOT
  type        = map(string)
  sensitive   = true
}

variable "pve_cluster_pbs_fingerprints" {
  description = <<EOT
    Map of PBS storage ID => TLS certificate fingerprint for certificate pinning. Optional
    when PBS uses a publicly-trusted ACME cert (Let's Encrypt). If needed, obtain via:
    proxmox-backup-manager cert info | grep Fingerprint. Sensitive value.
  EOT
  type        = map(string)
  sensitive   = true
  default     = {}
}


###############################################################################
## PVE node - core configuration
###############################################################################
variable "pve_node_core_subscription_keys" {
  description = <<EOT
    Map of Proxmox subscription keys (node name => key). If a node is not in the map
    or has an empty key, no subscription is set. Sensitive value.
  EOT
  type        = map(string)
  default     = {}
  sensitive   = true
}


###############################################################################
## Cloud-Init configurations
###############################################################################
variable "ci_secrets" {
  description = "A map of secrets used for cloud-init injection (e.g., Lego tokens). Sensitive value."
  type        = map(any)
  sensitive   = true
  default     = {}
}
