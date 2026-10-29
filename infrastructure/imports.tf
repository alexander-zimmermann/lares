###############################################################################
## Adoptions of resources that exist on the node before this configuration did
###############################################################################

## `vmbr0` was created by the Proxmox installer and carried the host's
## management address until VLAN 5. The import adopts it into the state; on a
## node where it is already adopted the block is a no-op.
import {
  to = module.pve_node_network_bridge["pve-1_vmbr0"].proxmox_network_linux_bridge.bridges[0]
  id = "pve-1:vmbr0"
}


###############################################################################
## PBS: jkossis/proxmox -> rfdrew/pbs
###############################################################################
## One apply moves every PBS object to the new provider without touching it:
## `removed` forgets the old resources, `import` adopts the objects under the
## new types. The SSH runs leave nothing on PBS to destroy.
locals {
  pbs_import_users = {
    for name, user in local.manifest.pbs_user : name => merge(user, {
      userid = "${name}@${try(user.realm, "pbs")}"
    })
  }

  pbs_import_realm_users = merge([
    for realm, cfg in local.manifest.pbs_realm_openid : {
      for name, acl in try(cfg.users, {}) : "${realm}/${name}" => merge(acl, {
        realm  = realm
        name   = name
        userid = "${name}@${realm}"
      })
    }
  ]...)
}

removed {
  from = module.pbs_realm_openid.proxmox_backup_server_realm_openid.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_realm_openid.proxmox_backup_server_user.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_realm_openid.proxmox_backup_server_acl.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_datastore.proxmox_backup_server_datastore.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_user.proxmox_backup_server_user.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_user.proxmox_backup_server_user_token.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_user.proxmox_backup_server_acl.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_user.proxmox_backup_server_acl.token
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_user.terraform_data.password
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_jobs.proxmox_backup_server_verify_job.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_jobs.terraform_data.prune
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_jobs.terraform_data.sync
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.pbs_acme.terraform_data.pbs_acme
  lifecycle {
    destroy = false
  }
}

import {
  for_each = local.manifest.pbs_realm_openid
  to       = module.pbs_realm_openid[each.key].pbs_realm_openid.this
  id       = each.key
}

import {
  for_each = local.pbs_import_realm_users
  to       = module.pbs_realm_openid[each.value.realm].pbs_user.this[each.value.name]
  id       = each.value.userid
}

import {
  for_each = local.pbs_import_realm_users
  to       = module.pbs_realm_openid[each.value.realm].pbs_acl.this[each.value.name]
  id       = "${each.value.path}|${each.value.userid}|${each.value.role_id}"
}

import {
  for_each = local.manifest.pbs_datastore
  to       = module.pbs_datastore[each.key].pbs_datastore.this
  id       = each.key
}

import {
  for_each = local.pbs_import_users
  to       = module.pbs_user[each.key].pbs_user.this
  id       = each.value.userid
}

import {
  for_each = local.pbs_import_users
  to       = module.pbs_user[each.key].pbs_acl.this
  id       = "${each.value.path}|${each.value.userid}|${each.value.role_id}"
}

import {
  for_each = { for name, user in local.pbs_import_users : name => user if try(user.create_token, false) }
  to       = module.pbs_user[each.key].pbs_api_token.this[0]
  id       = "${each.value.userid}!${each.value.token_name}"
}

import {
  for_each = { for name, user in local.pbs_import_users : name => user if try(user.create_token, false) }
  to       = module.pbs_user[each.key].pbs_acl.token[0]
  id       = "${each.value.path}|${each.value.userid}!${each.value.token_name}|${each.value.role_id}"
}

import {
  for_each = try(local.manifest.pbs_jobs.verify, {})
  to       = module.pbs_jobs.pbs_verify_job.this[each.key]
  id       = each.key
}

import {
  for_each = try(local.manifest.pbs_jobs.prune, {})
  to       = module.pbs_jobs.pbs_prune_job.this[each.key]
  id       = each.key
}

import {
  for_each = try(local.manifest.pbs_jobs.sync, {})
  to       = module.pbs_jobs.pbs_sync_job.this[each.key]
  id       = each.key
}

import {
  to = module.pbs_acme.pbs_acme_account.this
  id = local.manifest.pbs_acme.account_name
}

## The module's default plugin ID
import {
  to = module.pbs_acme.pbs_acme_plugin.this
  id = "cloudflare"
}

import {
  to = module.pbs_acme.pbs_node_acme.this
  id = "localhost"
}

import {
  to = module.pbs_acme.pbs_node_certificate.this
  id = "localhost"
}
