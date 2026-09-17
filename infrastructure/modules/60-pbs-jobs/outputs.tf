output "verify_job_ids" {
  description = "IDs of the verify jobs as registered in PBS."
  value       = [for k, v in proxmox_backup_server_verify_job.this : v.id]
}

output "prune_job_ids" {
  description = "IDs of the prune jobs applied over SSH."
  value       = keys(var.prune)
}

output "sync_job_ids" {
  description = "IDs of the sync jobs applied over SSH."
  value       = keys(var.sync)
}
