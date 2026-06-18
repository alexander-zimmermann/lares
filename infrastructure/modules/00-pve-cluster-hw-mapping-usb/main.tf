###############################################################################
## Provider Packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.110.0"
    }
  }
}


###############################################################################
## USB hardware mapping
###############################################################################
resource "proxmox_hardware_mapping_usb" "this" {
  name    = var.name
  comment = var.comment
  map     = var.map
}
