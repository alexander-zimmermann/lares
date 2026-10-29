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
