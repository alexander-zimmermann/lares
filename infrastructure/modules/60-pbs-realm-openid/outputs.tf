output "realm" {
  description = "Identifier of the realm as registered in PBS."
  value       = pbs_realm_openid.this.realm
}

output "user_ids" {
  description = "Map of login name => PBS user ID (`<name>@<realm>`)."
  value       = { for k, v in pbs_user.this : k => v.userid }
}
