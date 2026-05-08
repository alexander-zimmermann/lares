###############################################################################
## Server identity
###############################################################################
variable "name" {
  description = "Unique identifier of the metrics server entry in PVE."
  type        = string

  validation {
    condition     = length(var.name) > 0
    error_message = "name must be a non-empty string."
  }
}

variable "server" {
  description = "DNS name or IP address of the receiving OTel endpoint."
  type        = string
}

variable "port" {
  description = "TCP port of the receiving OTel endpoint."
  type        = number
}

variable "enable" {
  description = "Whether this metrics server is enabled."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "TCP socket timeout in seconds. PVE default is 1."
  type        = number
  default     = null
}


###############################################################################
## OpenTelemetry-specific
###############################################################################
variable "opentelemetry_compression" {
  description = "Compression algorithm. One of `none`, `gzip`. PVE default is `gzip`."
  type        = string
  default     = null
}

variable "opentelemetry_headers" {
  description = "Custom HTTP headers as JSON, base64 encoded. Sensitive."
  type        = string
  default     = null
  sensitive   = true
}

variable "opentelemetry_max_body_size" {
  description = "Maximum request body size in bytes. PVE default is 10000000."
  type        = number
  default     = null
}

variable "opentelemetry_path" {
  description = "OTel endpoint path (e.g. `/v1/metrics`)."
  type        = string
  default     = null
}

variable "opentelemetry_proto" {
  description = "Protocol for OTel. One of `http`, `https`. PVE default is `https`."
  type        = string
  default     = null
}

variable "opentelemetry_resource_attributes" {
  description = "Additional resource attributes as JSON, base64 encoded."
  type        = string
  default     = null
}

variable "opentelemetry_timeout" {
  description = "HTTP request timeout in seconds. PVE default is 5."
  type        = number
  default     = null
}

variable "opentelemetry_verify_ssl" {
  description = "Verify TLS certificate. PVE default is true."
  type        = bool
  default     = null
}
