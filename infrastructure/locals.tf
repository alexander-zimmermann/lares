###############################################################################
##  Manifest import & transformation
###############################################################################
locals {
  ## Manifest import. Scans the entire manifest directory and subdirectories for all YAML files, excluding schematics.yaml
  manifest_files = [
    for f in fileset("${path.module}/manifest", "**/*.yaml") : f
    if f != "20-image/schematics.yaml"
  ]

  ## Decodes all found YAML files into a list
  decoded_manifests = [
    for f in local.manifest_files :
    yamldecode(file("${path.module}/manifest/${f}"))
  ]

  ## Aggregate manifests by top-level keys
  manifest = {
    pve_cluster                = merge([for m in local.decoded_manifests : try(m.pve_cluster, {})]...)
    pve_cluster_users          = merge([for m in local.decoded_manifests : try(m.pve_cluster_users, {})]...)
    pve_cluster_acme           = merge([for m in local.decoded_manifests : try(m.pve_cluster_acme, {})]...)
    pve_cluster_pbs_storage    = merge([for m in local.decoded_manifests : try(m.pve_cluster_pbs_storage, {})]...)
    pve_cluster_backup_jobs    = merge([for m in local.decoded_manifests : try(m.pve_cluster_backup_jobs, {})]...)
    pve_cluster_hw_mapping_usb = merge([for m in local.decoded_manifests : try(m.pve_cluster_hw_mapping_usb, {})]...)
    pve_cluster_metrics_server = merge([for m in local.decoded_manifests : try(m.pve_cluster_metrics_server, {})]...)
    pve_node_core              = merge([for m in local.decoded_manifests : try(m.pve_node_core, {})]...)
    pve_node_network           = merge([for m in local.decoded_manifests : try(m.pve_node_network, {})]...)
    image                      = merge([for m in local.decoded_manifests : try(m.image, {})]...)
    ci_user_config             = merge([for m in local.decoded_manifests : try(m.ci_user_config, {})]...)
    ci_vendor_config           = merge([for m in local.decoded_manifests : try(m.ci_vendor_config, {})]...)
    ci_network_config          = merge([for m in local.decoded_manifests : try(m.ci_network_config, {})]...)
    ci_meta_config             = merge([for m in local.decoded_manifests : try(m.ci_meta_config, {})]...)
    template_vm                = merge([for m in local.decoded_manifests : try(m.template_vm, {})]...)
    template_lxc               = merge([for m in local.decoded_manifests : try(m.template_lxc, {})]...)
    fleet_vm                   = merge([for m in local.decoded_manifests : try(m.fleet_vm, {})]...)
    fleet_lxc                  = merge([for m in local.decoded_manifests : try(m.fleet_lxc, {})]...)
  }

  ## Shortcuts
  defaults = {
    target_node   = try(local.manifest.pve_cluster.defaults.target_node, {})
    file_storage  = try(local.manifest.pve_cluster.defaults.file_storage, {})
    block_storage = try(local.manifest.pve_cluster.defaults.block_storage, {})
  }
  pve_cluster = {
    api         = try(local.manifest.pve_cluster.api_connection, {})
    ssh         = try(local.manifest.pve_cluster.ssh_connection, {})
    nodes       = try(local.manifest.pve_cluster.nodes, {})
    users       = try(local.manifest.pve_cluster_users.users, {})
    acme        = try(local.manifest.pve_cluster_acme, {})
    pbs_storage = try(local.manifest.pve_cluster_pbs_storage, {})
    backup_jobs = try(local.manifest.pve_cluster_backup_jobs, {})
  }
  pve_node = {
    core = try(local.manifest.pve_node_core, {})
    network = {
      ## Flat list of all network bridge configurations
      bridges = merge([
        for node, config in try(local.manifest.pve_node_network.network_configuration, {}) : {
          for name, params in try(config.bridges, {}) : "${node}_${name}" => merge(params, {
            target_node = node
            name        = name
          })
        }
      ]...)
      ## Flat list of all network bond configurations
      bonds = merge([
        for node, config in try(local.manifest.pve_node_network.network_configuration, {}) : {
          for name, params in try(config.bonds, {}) : "${node}_${name}" => merge(params, {
            target_node = node
            name        = name
          })
        }
      ]...)
      ## Flat list of all network vlan configurations
      vlans = merge([
        for node, config in try(local.manifest.pve_node_network.network_configuration, {}) : {
          for name, params in try(config.vlans, {}) : "${node}_${name}" => merge(params, {
            target_node = node
            name        = name
          })
        }
      ]...)
    }
  }
}


###############################################################################
##  Virtual machine & container clones creation
###############################################################################
locals {
  ## Expanded map of `fleet_vm` derived from hybrid fleet_vm (map)
  fleet_vm = merge(
    ## Single objects: count == 0
    { for k, spec in local.manifest.fleet_vm : k => {
      template_id    = spec.template_id
      target_node    = try(spec.target_node, local.defaults.target_node)
      vm_id          = spec.vm_id
      wait_for_agent = try(spec.wait_for_agent, true)
      vm_name        = k ## No vm_name field in spec -> use key as name
      disks          = try(spec.disks, [])
      usb_devices    = try(spec.usb_devices, [])
      protection     = try(spec.protection, true)
    } if try(spec.count, 0) == 0 },

    ## Batch objects: count > 0
    merge([
      for group_key, spec in local.manifest.fleet_vm : {
        for i in range(1, spec.count + 1) : format("%s_%d", group_key, i) => {
          template_id    = spec.template_id
          target_node    = try(spec.target_node, local.defaults.target_node)
          vm_id          = spec.vm_id_start + i - 1
          wait_for_agent = try(spec.wait_for_agent, true)
          vm_name        = format("%s_%d", group_key, i)
          disks          = try(spec.disks, [])
          usb_devices    = try(spec.usb_devices, [])
          protection     = try(spec.protection, true)
        }
      } if try(spec.count, 0) > 0
    ]...)
  )

  ## Expanded map of `fleet_lxc` derived from hybrid fleet_lxc (map)
  fleet_lxc = merge(
    ## Single objects: count == 0
    { for k, spec in local.manifest.fleet_lxc : k => {
      template_id      = spec.template_id
      target_node      = try(spec.target_node, local.defaults.target_node)
      target_datastore = try(spec.target_datastore, local.defaults.block_storage)
      lxc_id           = spec.lxc_id
      container_name   = k ## No container_name field in spec -> use key as name
      protection       = try(spec.protection, true)
    } if try(spec.count, 0) == 0 },

    ## Batch objects: count > 0
    merge([
      for group_key, spec in local.manifest.fleet_lxc : {
        for i in range(1, spec.count + 1) : format("%s_%d", group_key, i) => {
          template_id      = spec.template_id
          target_node      = try(spec.target_node, local.defaults.target_node)
          target_datastore = try(spec.target_datastore, local.defaults.block_storage)
          lxc_id           = spec.lxc_id_start + i - 1
          container_name   = format("%s_%d", group_key, i)
          protection       = try(spec.protection, true)
        }
      } if try(spec.count, 0) > 0
    ]...)
  )
}
