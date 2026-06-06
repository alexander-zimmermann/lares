###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.109.0"
    }
  }
}


###############################################################################
## Virtual machine images
###############################################################################
resource "proxmox_download_file" "image" {
  count = var.image_url != "" && var.image_url != null ? 1 : 0

  node_name    = var.node
  datastore_id = var.datastore

  file_name          = var.image_filename
  url                = var.image_url
  checksum           = var.image_checksum
  checksum_algorithm = var.image_checksum_algorithm
  content_type       = var.image_type
  overwrite          = var.image_overwrite
  upload_timeout     = var.image_upload_timeout
}
