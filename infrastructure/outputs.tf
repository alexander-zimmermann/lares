###############################################################################
## PVE cluster - user configuration
###############################################################################
output "token_value" {
  description = <<EOT
    API token value for each managed user. This token is used for authenticating
    API requests to the Proxmox cluster. Only populated when a new token is created.
    Marked as sensitive to prevent exposure of credentials.
  EOT
  value       = { for k, v in module.pve_cluster_user : v.token_id => v.token_value if v.token_id != null }
  sensitive   = true
}


###############################################################################
## PVE cluster - ACME configuration
###############################################################################
output "acme_order_output" {
  description = <<EOT
    Log output from the `acme_order.sh` script, which includes DNS challenge
    validation, certificate request status, and installation results. Useful for
    debugging and auditing certificate provisioning. Marked as sensitive to avoid
    exposing internal details or domain information.
  EOT
  value       = module.pve_cluster_acme.acme_order_output
  sensitive   = true
}


###############################################################################
## PVE cluster - PBS storage configuration
###############################################################################
output "pbs_ready_output" {
  description = <<EOT
    Log output from the PBS readiness polling script for each configured PBS
    storage backend, which waits until the PBS API is reachable and the
    configured datastore is available. Marked as sensitive to avoid exposing
    credentials or internal system details.
  EOT
  value       = { for k, v in module.pve_cluster_pbs_storage : k => v.pbs_ready_output }
  sensitive   = true
}


###############################################################################
## PBS - core configuration
###############################################################################
output "pbs_core_output" {
  description = <<EOT
    Log output from the `pbs_core.sh` script, which sets the enterprise
    repository state and the subscription-nag hook on the PBS VM. Marked as
    sensitive to avoid exposing internal system details.
  EOT
  value       = module.pbs_core.pbs_core_output
  sensitive   = true
}


###############################################################################
## PVE node - core configuration
###############################################################################
output "local_content_type_output" {
  description = <<EOT
    Log output from the `local_content_types.sh` script for each Proxmox node.
    This output contains the detected or configured content types allowed on
    the `local` storage (e.g., `iso`, `vztmpl`, `snippets`). Useful for verifying
    storage capabilities across nodes. Marked as sensitive to avoid exposing
    internal system details.
  EOT
  value       = { for k, v in module.pve_node_core : k => v.local_content_type_output }
  sensitive   = true
}


###############################################################################
## PVE node - network configuration
###############################################################################
output "bond_output" {
  description = <<EOT
    Log output from the `setup_bond.sh` script, which configures network
    bonds on the Proxmox node. This output may include information about
    created bonds and any errors encountered during setup. Marked as
    sensitive to avoid exposing internal system details.
  EOT
  value       = { for k, v in module.pve_node_network_bond : k => v.bond_setup_output }
  sensitive   = true
}

output "vlan_output" {
  description = <<EOT
    Map of created VLAN interface resource identifiers. Each entry maps the
    VLAN configuration key to its corresponding Proxmox resource ID. These
    IDs can be used to reference VLAN interfaces in other modules or for
    resource management operations.
  EOT
  value       = { for k, v in module.pve_node_network_vlan : k => v.vlans }
  sensitive   = false
}

output "bridge_output" {
  description = <<EOT
    Map of created bridge interface resource identifiers. Each entry maps the
    bridge configuration key to its corresponding Proxmox resource ID. These
    IDs can be used to reference bridge interfaces in VM network configurations
    or other modules that require bridge resource identifiers.
  EOT
  value       = { for k, v in module.pve_node_network_bridge : k => v.bridges }
  sensitive   = false
}


###############################################################################
##  Virtual machine & container clones
###############################################################################
output "vms_id" {
  value = { for k, v in module.fleet_vm : k => v.id }
}

output "vms_ipv4" {
  value = { for k, v in module.fleet_vm : k => try(flatten(v.ipv4), []) }
}

output "vms_ipv6" {
  value = { for k, v in module.fleet_vm : k => try(flatten(v.ipv6), []) }
}

output "containers_id" {
  value = { for k, v in module.fleet_lxc : k => v.id }
}

output "containers_ipv4" {
  value = { for k, v in module.fleet_lxc : k => try(flatten(v.ipv4), []) }
}

output "containers_ipv6" {
  value = { for k, v in module.fleet_lxc : k => try(flatten(v.ipv6), []) }
}
