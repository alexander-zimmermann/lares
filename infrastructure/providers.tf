###############################################################################
## Proxmox provider
###############################################################################

## Default provider: non-root auth via API token + SSH user/key
provider "proxmox" {
  api_token = "${var.pve_cluster_token_id}=${var.pve_cluster_token_secret}"
  endpoint  = local.pve_cluster.api.api_url
  insecure  = local.pve_cluster.api.insecure

  ## unified SSH user/key + per-node addresses
  ssh {
    agent       = local.pve_cluster.ssh.agent
    username    = local.pve_cluster.ssh.username
    private_key = file(pathexpand(local.pve_cluster.ssh.private_key_path))

    dynamic "node" {
      for_each = local.pve_cluster.nodes

      content {
        name    = node.key
        address = node.value.address
        port    = node.value.port
      }
    }
  }
}

## Root-only provider alias, used sparingly, e.g. ACME account
provider "proxmox" {
  alias    = "root"
  endpoint = local.pve_cluster.api.api_url
  insecure = local.pve_cluster.api.insecure
  username = local.pve_cluster.api.username
  password = var.pve_cluster_password
}


###############################################################################
## Proxmox Backup Server provider
###############################################################################

## Root-only: the provider authenticates with a password ticket, and the
## password is the one cloud-init sets on the VM at first boot
provider "pbs" {
  endpoint     = local.pbs.api.api_url
  username     = local.pbs.api.username
  password     = var.ci_secrets.pbs_bootstrap_conf.pbs_root_password
  insecure_tls = local.pbs.api.insecure
}
