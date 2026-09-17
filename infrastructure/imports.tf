###############################################################################
## One-off adoption of objects created by pbs-bootstrap.sh
###############################################################################
## Import blocks are a no-op once the object is in state; each block leaves
## with the PR that follows its first apply.
import {
  to = module.pbs_jobs.proxmox_backup_server_verify_job.this["verify-datastore-primary"]
  id = "verify-datastore-primary"
}

import {
  to = module.pbs_jobs.proxmox_backup_server_verify_job.this["verify-datastore-secondary"]
  id = "verify-datastore-secondary"
}
