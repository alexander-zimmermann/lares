output "user_id" {
  description = "PBS user ID (`<username>@<realm>`)."
  value       = pbs_user.this.userid
}

output "token_id" {
  description = "Token auth ID (`<user_id>!<token_name>`), null when no token is created."
  value       = try(pbs_api_token.this[0].tokenid, null)
}

output "token_value" {
  description = <<EOT
    Token secret. PBS returns it only when the token is created or regenerated;
    an imported token has none. Sensitive value.
  EOT
  value       = try(pbs_api_token.this[0].value, null)
  sensitive   = true
}
