output "user_id" {
  description = "PBS user ID (`<username>@<realm>`)."
  value       = proxmox_backup_server_user.this.user_id
}

output "token_id" {
  description = "Token auth ID (`<user_id>!<token_name>`), null when no token is created."
  value       = try(proxmox_backup_server_user_token.this[0].id, null)
}

output "token_value" {
  description = <<EOT
    Token secret. PBS returns it only when the token is created or regenerated;
    an imported token has none. Sensitive value.
  EOT
  value       = try(proxmox_backup_server_user_token.this[0].value, null)
  sensitive   = true
}
