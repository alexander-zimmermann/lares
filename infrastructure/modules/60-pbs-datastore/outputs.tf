output "name" {
  description = "Name of the datastore as registered in PBS."
  value       = proxmox_backup_server_datastore.this.name
}

output "path" {
  description = "Absolute path of the datastore directory on the PBS VM."
  value       = proxmox_backup_server_datastore.this.path
}
