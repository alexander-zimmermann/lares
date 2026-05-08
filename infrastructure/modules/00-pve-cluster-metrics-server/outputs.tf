output "name" {
  description = "Name of the metrics server entry as registered in PVE."
  value       = proxmox_metrics_server.this.name
}
