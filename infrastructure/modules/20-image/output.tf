output "image_id" {
  description = <<EOT
    ID of the image file uploaded to the Proxmox node. This identifier can be
    used to reference the image in other resources, such as VM templates or
    ISO-based installations.

    When image_url is empty (manual upload), constructs the ID from datastore
    and filename. Otherwise, returns the ID from the downloaded resource.
  EOT
  value       = length(proxmox_download_file.image) > 0 ? proxmox_download_file.image[0].id : "${var.datastore}:${var.image_type}/${var.image_filename}"
}

output "image_type" {
  description = "Content type of the image (iso, import or vztmpl), known at plan time unlike image_id."
  value       = var.image_type
}
