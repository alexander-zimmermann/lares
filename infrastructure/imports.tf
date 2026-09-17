###############################################################################
## One-off adoption of objects created by pbs-bootstrap.sh
###############################################################################
## Import blocks are a no-op once the object is in state; each block leaves
## with the PR that follows its first apply.
import {
  to = module.pbs_datastore["datastore-primary"].proxmox_backup_server_datastore.this
  id = "datastore-primary"
}

import {
  to = module.pbs_datastore["datastore-secondary"].proxmox_backup_server_datastore.this
  id = "datastore-secondary"
}
