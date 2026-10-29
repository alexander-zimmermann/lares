output "verify_job_ids" {
  description = "IDs of the verify jobs as registered in PBS."
  value       = [for k, v in pbs_verify_job.this : v.id]
}

output "prune_job_ids" {
  description = "IDs of the prune jobs as registered in PBS."
  value       = [for k, v in pbs_prune_job.this : v.id]
}

output "sync_job_ids" {
  description = "IDs of the sync jobs as registered in PBS."
  value       = [for k, v in pbs_sync_job.this : v.id]
}
