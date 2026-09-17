output "realm" {
  description = "Identifier of the realm as registered in PBS."
  value       = proxmox_backup_server_realm_openid.this.realm
}

output "user_ids" {
  description = "Map of login name => PBS user ID (`<name>@<realm>`)."
  value       = { for k, v in proxmox_backup_server_user.this : k => v.user_id }
}
