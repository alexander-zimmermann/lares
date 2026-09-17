output "id" {
  description = "Identifier of the registered storage backend in Proxmox."
  value       = proxmox_storage_pbs.this.id
}
