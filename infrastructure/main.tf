###############################################################################
## PVE cluster - user configuration
###############################################################################
module "pve_cluster_user" {
  source   = "./modules/00-pve-cluster-user"
  for_each = local.pve_cluster.users

  ## User identity and authentication
  username   = each.key
  password   = try(var.pve_cluster_user_passwords[each.key], null)
  realm      = try(each.value.realm, "pve")
  enabled    = try(each.value.enabled, true)
  first_name = try(each.value.first_name, null)
  last_name  = try(each.value.last_name, null)
  email      = try(each.value.email, null)
  comment    = try(each.value.comment, "Managed by OpenTofu")

  ## Role and permissions
  role_id         = try(each.value.role_id, null)
  create_role     = try(each.value.create_role, false)
  role_privileges = try(each.value.role_privileges, [])

  ## Token configuration
  create_token          = try(each.value.create_token, false)
  token_name            = try(each.value.token_name, null)
  privileges_separation = try(each.value.privileges_separation, false)

  ## ACL configuration
  path      = try(each.value.path, null)
  propagate = try(each.value.propagate, true)
}


###############################################################################
## PVE cluster - ACME configuration
###############################################################################
module "pve_cluster_acme" {
  source = "./modules/00-pve-cluster-acme"

  ## Pass the aliased provider to satisfy the state reference
  providers = {
    proxmox.root = proxmox.root
  }

  ## SSH connection (required for acme changes)
  ssh_hostname    = local.pve_cluster.nodes[local.pve_cluster.acme.target_node].address
  ssh_username    = local.pve_cluster.ssh.username
  ssh_private_key = local.pve_cluster.ssh.private_key_path

  ## ACME Account
  account_name  = local.pve_cluster.acme.account_name
  contact_email = local.pve_cluster.acme.contact_email

  ## Certificate Configuration
  primary_domain = local.pve_cluster.acme.primary_domain
  san_domains    = local.pve_cluster.acme.san_domains
  cf_token       = var.pve_cluster_acme_cf_token
  cf_zone_id     = var.pve_cluster_acme_cf_zone_id
  cf_account_id  = var.pve_cluster_acme_cf_account_id
}


###############################################################################
## PVE cluster - PBS storage configuration
###############################################################################
module "pve_cluster_pbs_storage" {
  source   = "./modules/00-pve-cluster-pbs-storage"
  for_each = local.pve_cluster.pbs_storage

  depends_on = [module.fleet_vm["backup_server_01"]]

  ## Storage identity
  storage_id = each.key
  server     = each.value.pbs.server
  datastore  = each.value.pbs.datastore
  nodes      = try(each.value.nodes, null)

  ## PBS connection
  username    = each.value.pbs.username
  password    = var.pve_cluster_pbs_passwords[each.key]
  fingerprint = try(var.pve_cluster_pbs_fingerprints[each.key], null)
}


###############################################################################
## PVE cluster - backup jobs
###############################################################################
module "pve_cluster_backup_jobs" {
  source   = "./modules/00-pve-cluster-backup-jobs"
  for_each = local.pve_cluster.backup_jobs

  depends_on = [module.pve_cluster_pbs_storage]

  ## Backup job identity
  job_id   = each.key
  schedule = each.value.schedule

  ## Backup target
  storage = each.value.storage
  vmids   = each.value.vmids

  ## Backup options
  mode     = try(each.value.mode, "snapshot")
  compress = try(each.value.compress, "zstd")

  ## Host CPU/IO throttling (optional)
  zstd        = try(each.value.zstd, null)
  max_workers = try(each.value.max_workers, null)
  ionice      = try(each.value.ionice, null)
  bwlimit     = try(each.value.bwlimit, null)
}


###############################################################################
## PVE cluster - USB hardware mappings
###############################################################################
module "pve_cluster_hw_mapping_usb" {
  source   = "./modules/00-pve-cluster-hw-mapping-usb"
  for_each = local.manifest.pve_cluster_hw_mapping_usb

  name    = each.key
  comment = try(each.value.comment, null)
  map     = each.value.map
}


###############################################################################
## PVE cluster - OpenTelemetry metrics server
###############################################################################
module "pve_cluster_metrics_server" {
  source   = "./modules/00-pve-cluster-metrics-server"
  for_each = local.manifest.pve_cluster_metrics_server

  name   = each.key
  server = each.value.server
  port   = each.value.port
  enable = try(each.value.enable, true)

  opentelemetry_compression         = try(each.value.opentelemetry_compression, null)
  opentelemetry_headers             = try(each.value.opentelemetry_headers, null)
  opentelemetry_max_body_size       = try(each.value.opentelemetry_max_body_size, null)
  opentelemetry_path                = try(each.value.opentelemetry_path, null)
  opentelemetry_proto               = try(each.value.opentelemetry_proto, null)
  opentelemetry_resource_attributes = try(each.value.opentelemetry_resource_attributes, null)
  opentelemetry_timeout             = try(each.value.opentelemetry_timeout, null)
  opentelemetry_verify_ssl          = try(each.value.opentelemetry_verify_ssl, null)
}


###############################################################################
## PVE node - core configuration
###############################################################################
module "pve_node_core" {
  source   = "./modules/10-pve-node-core"
  for_each = local.pve_cluster.nodes

  ## SSH connection (required for local content type changes)
  ssh_hostname    = local.pve_cluster.nodes[each.key].address
  ssh_username    = local.pve_cluster.ssh.username
  ssh_private_key = local.pve_cluster.ssh.private_key_path

  ## Node placement
  node = each.key

  ## Timezone and DNS configuration
  timezone          = local.pve_node.core[each.key].timezone
  dns_servers       = local.pve_node.core[each.key].dns.servers
  dns_search_domain = local.pve_node.core[each.key].dns.search_domain

  ## Subscription key & repository configuration.
  ## Default to "" for nodes absent from the map — the module treats "" as
  ## "no subscription", matching the variable's documented contract.
  proxmox_subscription_key          = try(var.pve_node_core_subscription_keys[each.key], "")
  enable_no_subscription_repository = try(local.pve_node.core[each.key].repositories.no_subscription, true)
  enable_enterprise_repository      = try(local.pve_node.core[each.key].repositories.enterprise, false)
  enable_ceph_repository            = try(local.pve_node.core[each.key].repositories.ceph, false)

  ## Local content types
  local_content_types = local.pve_node.core[each.key].local_content_types
}


###############################################################################
## PVE node - network configuration
###############################################################################
module "pve_node_network_bond" {
  source      = "./modules/10-pve-node-network"
  for_each    = local.pve_node.network.bonds
  create_bond = true

  ## SSH connection (required for network changes)
  ssh_hostname    = local.pve_cluster.nodes[each.value.target_node].address
  ssh_username    = local.pve_cluster.ssh.username
  ssh_private_key = local.pve_cluster.ssh.private_key_path

  ## Node placement
  name = each.value.name
  node = local.pve_cluster.nodes[each.value.target_node].node_name

  ## Bonding configuration
  mode        = each.value.mode
  slaves      = each.value.slaves
  miimon      = each.value.miimon
  lacp_rate   = each.value.lacp_rate
  hash_policy = each.value.hash_policy
  primary     = each.value.primary

  ## Network configuration
  mtu      = each.value.mtu
  address  = each.value.address
  address6 = each.value.address6
  gateway  = each.value.gateway
  gateway6 = each.value.gateway6

  ## Interface options
  autostart = each.value.autostart
  comment   = each.value.comment
}

module "pve_node_network_vlan" {
  source      = "./modules/10-pve-node-network"
  for_each    = local.pve_node.network.vlans
  create_vlan = true

  ## SSH connection (required for network changes)
  ssh_hostname    = local.pve_cluster.nodes[each.value.target_node].address
  ssh_username    = local.pve_cluster.ssh.username
  ssh_private_key = local.pve_cluster.ssh.private_key_path

  ## Node placement
  name = each.value.name
  node = local.pve_cluster.nodes[each.value.target_node].node_name

  ## VLAN configuration
  interface = each.value.interface
  vlan      = each.value.vlan

  ## Network configuration
  address  = each.value.address
  address6 = each.value.address6
  gateway  = each.value.gateway
  gateway6 = each.value.gateway6
  mtu      = each.value.mtu

  ## Interface options
  autostart = each.value.autostart
  comment   = each.value.comment
}

module "pve_node_network_bridge" {
  source        = "./modules/10-pve-node-network"
  for_each      = local.pve_node.network.bridges
  create_bridge = true
  depends_on    = [module.pve_node_network_bond, module.pve_node_network_vlan]

  ## SSH connection (required for network changes)
  ssh_hostname    = local.pve_cluster.nodes[each.value.target_node].address
  ssh_username    = local.pve_cluster.ssh.username
  ssh_private_key = local.pve_cluster.ssh.private_key_path

  ## Node placement
  name = each.value.name
  node = local.pve_cluster.nodes[each.value.target_node].node_name

  ## Bridge configuration
  ports      = each.value.ports
  vlan_aware = each.value.vlan_aware

  ## Network configuration
  address  = each.value.address
  address6 = each.value.address6
  gateway  = each.value.gateway
  gateway6 = each.value.gateway6
  mtu      = each.value.mtu

  ## Interface options
  autostart = each.value.autostart
  comment   = each.value.comment
}


###############################################################################
## Virtual machine & container images
###############################################################################
module "image" {
  source   = "./modules/20-image"
  for_each = local.manifest.image

  ## Storage configuration
  node      = try(each.value.target_node, local.defaults.target_node)
  datastore = try(each.value.target_datastore, local.defaults.file_storage)

  ## Image source and verification
  image_filename           = each.value.image_filename
  image_url                = each.value.image_url
  image_checksum           = each.value.image_checksum
  image_checksum_algorithm = try(each.value.image_checksum_algorithm, "sha256")
  image_type               = each.value.image_type
}


###############################################################################
## Cloud-Init configurations
###############################################################################
module "cloud_init_user_config" {
  source             = "./modules/30-cloud-init"
  for_each           = local.manifest.ci_user_config
  create_user_config = true

  ## Storage configuration
  node      = try(each.value.target_node, local.defaults.target_node)
  datastore = try(each.value.target_datastore, local.defaults.file_storage)
  filename  = "${each.key}-user-config.yaml"

  ## User account configuration
  users = each.value
}

module "cloud_init_vendor_config" {
  source               = "./modules/30-cloud-init"
  for_each             = local.manifest.ci_vendor_config
  create_vendor_config = true

  ## Storage configuration (rootfs)
  node      = try(each.value.target_node, local.defaults.target_node)
  datastore = try(each.value.target_datastore, local.defaults.file_storage)
  filename  = "${each.key}-vendor-config.yaml"

  ## Package management
  apt                        = try(each.value.apt, {})
  snap                       = try(each.value.snap, {})
  packages                   = try(each.value.packages, [])
  package_update             = try(each.value.package_update, true)
  package_upgrade            = try(each.value.package_upgrade, true)
  package_reboot_if_required = try(each.value.package_reboot_if_required, true)

  ## Localization
  locale   = try(each.value.locale, "")
  timezone = try(each.value.timezone, "Europe/Berlin")

  ## Custom commands
  runcmd  = try(each.value.runcmd, [])
  bootcmd = try(each.value.bootcmd, [])

  ## Disk configuration (additional disks)
  disk_setup = try(each.value.disk_setup, {})
  fs_setup   = try(each.value.fs_setup, [])

  ## Mounts
  mounts               = try(each.value.mounts, [])
  mount_default_fields = try(each.value.mount_default_fields, [])

  ## File management
  write_files = [
    for wf in try(each.value.write_files, []) : {
      path        = wf.path
      permissions = try(wf.permissions, "0644")
      owner       = try(wf.owner, "root:root")
      encoding    = try(wf.encoding, "text/plain")
      append      = try(wf.append, false)
      defer       = try(wf.defer, false)
      trim        = try(wf.secret_ref, null) != null
      content = try(wf.template_file, null) != null ? templatefile(wf.template_file, merge(
        ## Priority 1: Render template with merged context (Manifest Vars + OpenTofu Secrets)
        try(wf.vars, {}),
        try(wf.secret_ref, null) != null ? try(var.ci_secrets[wf.secret_ref], {}) : {},
        ## Generated API token credentials from pve_cluster_user module
        try(wf.generated_token, null) != null ? {
          (wf.generated_token.template_var_id)     = module.pve_cluster_user[wf.generated_token.user].token_id
          (wf.generated_token.template_var_secret) = module.pve_cluster_user[wf.generated_token.user].token_value
        } : {}
        )) : join("\n", compact([
          ## Priority 2: Auto-generate Key-Value list from Secrets (if no template)
          try(wf.secret_ref, null) != null ? join("\n", [for k, v in var.ci_secrets[wf.secret_ref] : "${k}=\"${v}\""]) : "",
          ## Priority 3: Auto-generate Key-Value list from Vars (if no template)
          try(wf.secret_ref, null) != null && try(wf.vars, null) != null ? join("\n", [for k, v in wf.vars : "${k}=\"${v}\""]) : "",
          ## Priority 4: Fallback to standard content/file logic
          try(wf.secret_ref, null) == null ? (
            try(wf.content_file, null) != null ? file(wf.content_file) :
            try(wf.content, "")
          ) : ""
      ]))
    }
  ]
}

module "cloud_init_network_config" {
  source                = "./modules/30-cloud-init"
  for_each              = local.manifest.ci_network_config
  create_network_config = true

  ## Storage configuration
  node      = try(each.value.target_node, local.defaults.target_node)
  datastore = try(each.value.target_datastore, local.defaults.file_storage)
  filename  = "${each.key}-network-config.yaml"

  ## DHCP configuration
  dhcp4     = each.value.dhcp4
  dhcp6     = each.value.dhcp6
  accept_ra = each.value.accept_ra

  ## Static IP configuration
  ipv4_address = try(each.value.ipv4_address, "")
  ipv6_address = try(each.value.ipv6_address, "")
  gateway4     = try(each.value.ipv4_gateway, "")
  gateway6     = try(each.value.ipv6_gateway, "")

  ## DNS configuration
  dns_servers       = try(each.value.dns_servers, ["1.1.1.1", "2606:4700:4700::1111"])
  dns_search_domain = try(each.value.dns_search_domain, [])
}

module "cloud_init_meta_config" {
  source             = "./modules/30-cloud-init"
  for_each           = local.manifest.ci_meta_config
  create_meta_config = true

  ## Storage configuration
  node      = try(each.value.target_node, local.defaults.target_node)
  datastore = try(each.value.target_datastore, local.defaults.file_storage)
  filename  = "${each.key}-meta-config.yaml"

  ## System identity
  hostname = each.value.hostname
}


###############################################################################
##  Virtual machine & container templates
###############################################################################
module "template_vm" {
  source   = "./modules/40-template-vm"
  for_each = local.manifest.template_vm

  ## Infrastructure placement
  node           = try(each.value.target_node, local.defaults.target_node)
  disk_datastore = try(each.value.target_datastore, local.defaults.block_storage)

  ## VM identification
  name        = "${each.key}-template"
  vm_id       = each.value.vm_id
  description = try(each.value.description, "Created by OpenTofu")
  tags        = try(each.value.tags, ["opentofu", "template", "vm"])

  ## Hardware configuration
  bios         = try(each.value.bios, "seabios")
  machine_type = lookup(each.value, "machine_type", null)
  boot_order   = lookup(each.value, "boot_order", null)
  cores        = each.value.cores
  memory       = each.value.memory

  ## Disk and image configuration
  image_id  = try(module.image[each.value.image_id].image_id, null)
  os_type   = each.value.os_type
  disk_size = each.value.disk_size

  ## Cloud-init configuration
  enable_cloud_init = lookup(each.value, "enable_cloud_init", true)
  ci_interface      = try(each.value.ci_interface, null)
  ci_user_data      = try(module.cloud_init_user_config[each.value.ci_user_config].user_data_file_id, null)
  ci_vendor_data    = try(module.cloud_init_vendor_config[each.value.ci_vendor_config].vendor_data_file_id, null)
  ci_network_data   = try(module.cloud_init_network_config[each.value.ci_network_config].network_data_file_id, null)
  ci_meta_data      = try(module.cloud_init_meta_config[each.value.ci_meta_config].meta_data_file_id, null)

  ## Security and UEFI configuration (Windows 11 / modern OS)
  enable_tpm  = lookup(each.value, "enable_tpm", false)
  secure_boot = lookup(each.value, "secure_boot", false)

  ## Network configuration
  vnic_bridge = try(each.value.vnic_bridge, "vmbr0")
  vnic_model  = try(each.value.vnic_model, "virtio")
  vlan_tag    = try(each.value.vlan_tag, null)
}

module "template_lxc" {
  source   = "./modules/40-template-lxc"
  for_each = local.manifest.template_lxc

  ## Infrastructure placement
  node           = try(each.value.target_node, local.defaults.target_node)
  disk_datastore = try(each.value.target_datastore, local.defaults.block_storage)

  ## Container identification
  name         = "${each.key}-template"
  lxc_id       = each.value.lxc_id
  description  = try(each.value.description, "Created by OpenTofu")
  tags         = try(each.value.tags, ["opentofu", "template", "lxc"])
  unprivileged = try(each.value.unprivileged, true)
  image_id     = try(module.image[each.value.image_id].image_id, null)

  ## Resource allocation
  cores       = each.value.cores
  memory      = each.value.memory
  memory_swap = try(each.value.memory_swap, 512)
  disk_size   = each.value.disk_size

  ## Operating system configuration
  os_type = each.value.os_type

  ## Network configuration
  vnic_name         = try(each.value.vnic_name, "eth0")
  vnic_bridge       = try(each.value.vnic_bridge, "vmbr0")
  vlan_tag          = try(each.value.vlan_tag, null)
  dns_servers       = try(each.value.dns_servers, ["1.1.1.1", "2606:4700:4700::1111"])
  dns_search_domain = try(each.value.dns_search_domain, [])
}


###############################################################################
##  Virtual machine & container clones
###############################################################################
module "fleet_vm" {
  source   = "./modules/50-fleet-vm"
  for_each = local.fleet_vm

  ## VM placement and identification
  node  = each.value.target_node
  vm_id = each.value.vm_id
  name  = each.value.vm_name

  ## Used VM template
  template_id   = module.template_vm[each.value.template_id].vmid
  template_node = module.template_vm[each.value.template_id].node

  ## Startup variables
  wait_for_agent = each.value.wait_for_agent
  protection     = each.value.protection

  ## Cloud-init configuration (inherited from template)
  cloud-init_override = true
  ci_datastore        = try(each.value.target_datastore, local.defaults.block_storage)
  ci_user_data        = module.template_vm[each.value.template_id].ci_user_data
  ci_vendor_data      = module.template_vm[each.value.template_id].ci_vendor_data
  ci_network_data     = module.template_vm[each.value.template_id].ci_network_data
  ci_meta_data        = module.template_vm[each.value.template_id].ci_meta_data

  ## Additional disks
  disks = [
    for d in try(each.value.disks, []) : merge(d, {
      disk_datastore = try(d.disk_datastore, local.defaults.block_storage)
    })
  ]

  ## USB device passthrough
  usb_devices = try(each.value.usb_devices, [])
}

module "fleet_lxc" {
  source   = "./modules/50-fleet-lxc"
  for_each = local.fleet_lxc

  ## Container placement and identification
  node      = each.value.target_node
  datastore = each.value.target_datastore
  lxc_id    = each.value.lxc_id
  name      = each.value.container_name

  ## Used container template
  template_id   = module.template_lxc[each.value.template_id].lxc_id
  template_node = module.template_lxc[each.value.template_id].node

  ## Startup variables
  protection = each.value.protection
}
