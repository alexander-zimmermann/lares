output "certificate_fingerprint" {
  description = "SHA-256 fingerprint of the certificate PBS serves; it changes with every renewal."
  value       = pbs_node_certificate.this.fingerprint
}
