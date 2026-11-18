terraform {
  required_version = ">= 1.11.0" # OpenTofu

  required_providers {
    proxmox = {
      ## https://search.opentofu.org/provider/bpg/proxmox/latest
      source  = "bpg/proxmox"
      version = "0.123.1"
    }
    pbs = {
      ## https://search.opentofu.org/provider/rfdrew/pbs/latest
      source  = "rfdrew/pbs"
      version = "1.0.0"
    }
    external = {
      ## https://search.opentofu.org/provider/hashicorp/external/latest
      source  = "hashicorp/external"
      version = "2.4.2"
    }
    local = {
      ## https://search.opentofu.org/provider/hashicorp/local/latest
      source  = "hashicorp/local"
      version = "2.9.1"
    }
  }
}
