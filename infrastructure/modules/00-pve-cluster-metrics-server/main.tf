###############################################################################
## Provider Packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.107.0"
    }
  }
}


###############################################################################
## PVE OpenTelemetry metrics server
###############################################################################
resource "proxmox_metrics_server" "this" {
  name   = var.name
  type   = "opentelemetry"
  server = var.server
  port   = var.port

  disable = !var.enable
  timeout = var.timeout

  opentelemetry_compression         = var.opentelemetry_compression
  opentelemetry_headers             = var.opentelemetry_headers
  opentelemetry_max_body_size       = var.opentelemetry_max_body_size
  opentelemetry_path                = var.opentelemetry_path
  opentelemetry_proto               = var.opentelemetry_proto
  opentelemetry_resource_attributes = var.opentelemetry_resource_attributes
  opentelemetry_timeout             = var.opentelemetry_timeout
  opentelemetry_verify_ssl          = var.opentelemetry_verify_ssl
}
