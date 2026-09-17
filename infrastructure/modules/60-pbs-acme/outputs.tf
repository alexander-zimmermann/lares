output "pbs_acme_output" {
  description = <<EOT
    Log output from the `pbs_acme.sh` script, which registers the ACME
    account and DNS plugin on the PBS VM and orders the certificate when
    needed. Marked as sensitive to avoid exposing internal system details.
  EOT
  value       = try(data.external.pbs_acme_output.result.output, "No log output available.")
  sensitive   = true
}
