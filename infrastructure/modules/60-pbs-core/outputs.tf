output "pbs_core_output" {
  description = <<EOT
    Log output from the `pbs_core.sh` script, which sets the enterprise
    repository state and the subscription-nag hook on the PBS VM. Marked as
    sensitive to avoid exposing internal system details.
  EOT
  value       = try(data.external.pbs_core_output.result.output, "No log output available.")
  sensitive   = true
}
