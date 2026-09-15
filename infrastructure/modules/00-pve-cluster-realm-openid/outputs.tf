output "realm" {
  description = "Identifier of the realm as registered in PVE."
  value       = proxmox_realm_openid.this.realm
}

output "group_ids" {
  description = "Map of claim group name => PVE group ID."
  value       = { for k, v in proxmox_virtual_environment_group.this : k => v.group_id }
}
