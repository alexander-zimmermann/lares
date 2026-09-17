###############################################################################
## APT repositories & subscription nag
###############################################################################
variable "enable_enterprise_repository" {
  description = "Enable the PBS enterprise repository. Needs a subscription key on the VM."
  type        = bool
  default     = false
}

variable "subscription_nag" {
  description = <<EOT
    Keep the "No valid subscription" dialog in the web UI. When false, an APT
    hook patches it out of proxmoxlib.js after every proxmox-widget-toolkit
    install or upgrade.
  EOT
  type        = bool
  default     = false
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
