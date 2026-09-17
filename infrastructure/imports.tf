###############################################################################
## One-off adoption of objects created by pbs-bootstrap.sh
###############################################################################
## Import blocks are a no-op once the object is in state; each block leaves
## with the PR that follows its first apply.
import {
  to = module.pbs_user["alexander"].proxmox_backup_server_user.this
  id = "alexander@pbs"
}

import {
  to = module.pbs_user["alexander"].proxmox_backup_server_acl.this
  id = "/|alexander@pbs|Admin"
}

import {
  to = module.pbs_user["backup"].proxmox_backup_server_user.this
  id = "backup@pbs"
}

import {
  to = module.pbs_user["backup"].proxmox_backup_server_acl.this
  id = "/datastore/datastore-primary|backup@pbs|DatastoreAdmin"
}

import {
  to = module.pbs_user["homepage"].proxmox_backup_server_user.this
  id = "homepage@pbs"
}

import {
  to = module.pbs_user["homepage"].proxmox_backup_server_acl.this
  id = "/|homepage@pbs|Audit"
}

import {
  to = module.pbs_user["homepage"].proxmox_backup_server_user_token.this[0]
  id = "homepage@pbs!homepage"
}

import {
  to = module.pbs_user["homepage"].proxmox_backup_server_acl.token[0]
  id = "/|homepage@pbs!homepage|Audit"
}

import {
  to = module.pbs_user["metrics"].proxmox_backup_server_user.this
  id = "metrics@pbs"
}

import {
  to = module.pbs_user["metrics"].proxmox_backup_server_acl.this
  id = "/|metrics@pbs|Audit"
}

import {
  to = module.pbs_user["metrics"].proxmox_backup_server_user_token.this[0]
  id = "metrics@pbs!metrics"
}

import {
  to = module.pbs_user["metrics"].proxmox_backup_server_acl.token[0]
  id = "/|metrics@pbs!metrics|Audit"
}
