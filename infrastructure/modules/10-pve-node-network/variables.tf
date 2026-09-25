###############################################################################
##  General variables for the module
###############################################################################
variable "node" {
  description = <<EOT
    Name of the Proxmox node where the network interface will be configured.
    This should match the node name as defined in your Proxmox cluster (e.g., `pve`).
  EOT
  type        = string

  validation {
    condition     = length(var.node) > 0
    error_message = "node must be a non-empty string."
  }
}

variable "name" {
  description = <<EOT
    Name of the network interface to be created. For bridges, use names like `vmbr1`,
    for bonds use `bond0`, for VLANs use either dot notation (`eno1.100`) or custom
    names (`vlan-mgmt`). Must follow Linux network interface naming conventions.
  EOT
  type        = string

  validation {
    condition     = length(var.name) > 0
    error_message = "name must be a non-empty string."
  }
}

variable "address" {
  description = <<EOT
    IPv4 address in CIDR notation to assign to the network interface (e.g., `192.168.1.10/24`).
    When specified, the interface will be configured with a static IP address.
    Set to `null` to disable IPv4 address assignment.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.address == null || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.address))
    error_message = "address must be a valid IPv4 address in CIDR notation (e.g., '192.168.1.10/24') or null."
  }
}

variable "address6" {
  description = <<EOT
    IPv6 address in CIDR notation to assign to the network interface (e.g., `2001:db8::1/64`).
    When specified, the interface will be configured with a static IPv6 address.
    Set to `null` to disable IPv6 address assignment.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.address6 == null || can(regex("^[0-9a-fA-F:]+/[0-9]{1,3}$", var.address6))
    error_message = "address6 must be a valid IPv6 address in CIDR notation (e.g., '2001:db8::1/64') or null."
  }
}

variable "gateway" {
  description = <<EOT
    IPv4 gateway address for routing traffic from this interface (e.g., `192.168.1.1`).
    This is typically the router or default gateway on the network segment.
    Set to `null` if no IPv4 gateway is needed.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.gateway == null || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.gateway))
    error_message = "gateway must be a valid IPv4 address (e.g., '192.168.1.1') or null."
  }
}

variable "gateway6" {
  description = <<EOT
    IPv6 gateway address for routing traffic from this interface (e.g., `2001:db8::1`).
    This is typically the IPv6 router or default gateway on the network segment.
    Set to `null` if no IPv6 gateway is needed.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.gateway6 == null || can(regex("^[0-9a-fA-F:]+$", var.gateway6))
    error_message = "gateway6 must be a valid IPv6 address (e.g., '2001:db8::1') or null."
  }
}

variable "mtu" {
  description = <<EOT
    Maximum Transmission Unit (MTU) size in bytes for the network interface.
    Standard Ethernet MTU is `1500`, jumbo frames typically use `9000`.
    Set to `null` to use the system default MTU value.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.mtu == null || (var.mtu >= 68 && var.mtu <= 9000)
    error_message = "mtu must be between 68 and 9000 bytes (valid Ethernet range) or null."
  }
}

variable "autostart" {
  description = <<EOT
    Whether to automatically bring up the network interface at boot time.
    When `true`, the interface will be started automatically during system initialization.
    Set to `null` to use the system default behavior.
  EOT
  type        = bool
  default     = null
}

variable "reload" {
  description = <<EOT
    Whether the node reloads its network configuration after this interface is
    created, updated or deleted. When `false`, the change is only staged on the
    node (`/etc/network/interfaces.new`) and takes effect on the next reload,
    from the Proxmox UI or `ifreload -a`. Set to `null` to use the provider
    default (`true`).
  EOT
  type        = bool
  default     = null
}

variable "comment" {
  description = <<EOT
    Optional comment or description for the network interface configuration.
    This is useful for documentation purposes and appears in the Proxmox interface.
    Set to `null` if no comment is needed.
  EOT
  type        = string
  default     = null
}


###############################################################################
## Bonds
###############################################################################
variable "create_bond" {
  description = <<EOT
    Flag to enable creation and maintenance of bond interfaces. When true,
    bond interfaces will be configured by directly editing `/etc/network/interfaces`
    and applying changes with `ifreload -a` via SSH. Defaults to `false`.
  EOT
  type        = bool
  default     = false
}

variable "ssh_hostname" {
  description = <<EOT
    Hostname or IP address of the Proxmox node used for SSH access.
    This must be reachable from the system executing the configuration.
  EOT
  type        = string
  default     = null
}

variable "ssh_username" {
  description = <<EOT
    SSH username with root privileges on the Proxmox node.
    Defaults to `root`.
  EOT
  type        = string
  default     = "root"
}

variable "ssh_private_key" {
  description = <<EOT
    PEM-encoded private key used for SSH authentication to the Proxmox node.
    This key must allow access to the specified user and host. Sensitive value.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_port" {
  description = <<EOT
    SSH port used to connect to the Proxmox node. Defaults to `22`.
  EOT
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535
    error_message = "ssh_port must be a valid port number between 1 and 65535."
  }
}

variable "mode" {
  description = <<EOT
    Linux bonding mode for the bond interface. Supported modes include:
    - `802.3ad`: LACP (IEEE 802.3ad Dynamic link aggregation)
    - `active-backup`: Fault-tolerance (active-backup policy)
    - `balance-xor`: XOR (balance-xor policy)
    - `balance-tlb`: Adaptive transmit load balancing
    - `balance-alb`: Adaptive load balancing
    - `balance-rr`: Round-robin (balance-rr policy)
    - `broadcast`: Broadcast (broadcast policy)
  EOT
  type        = string
  default     = null

  validation {
    condition = var.mode == null || contains([
      "802.3ad",
      "active-backup",
      "balance-xor",
      "balance-tlb",
      "balance-alb",
      "balance-rr",
      "broadcast"
    ], var.mode)
    error_message = "mode must be one of: 802.3ad, active-backup, balance-xor, balance-tlb, balance-alb, balance-rr, broadcast, or null."
  }
}

variable "slaves" {
  description = <<EOT
    List of physical network interface names to aggregate into the bond.
    Example: `["eno1", "eno2"]`. At least two interfaces are required for
    redundancy and load balancing. Interface names must match the actual
    network device names on the Proxmox node.
  EOT
  type        = list(string)
  default     = null

  validation {
    condition     = var.slaves == null || length(var.slaves) >= 2
    error_message = "slaves must contain at least 2 interface names if provided."
  }

  validation {
    condition     = var.slaves == null || alltrue([for slave in var.slaves : length(trimspace(slave)) > 0])
    error_message = "All slave interface names must be non-empty strings."
  }
}

variable "miimon" {
  description = <<EOT
    MII (Media Independent Interface) monitoring interval in milliseconds for link failure detection.
    The bond driver will check link status at this interval. Common values are `100` (default)
    for responsive failover, or higher values like `200-1000` for reduced system load.
    Set to `0` to disable MII monitoring.
  EOT
  type        = number
  default     = 100

  validation {
    condition     = var.miimon == null || (var.miimon >= 50 && var.miimon <= 1000)
    error_message = "miimon must be between 50 and 1000 milliseconds (standard range for stability) or null."
  }
}

variable "lacp_rate" {
  description = <<EOT
    LACP (Link Aggregation Control Protocol) negotiation rate for 802.3ad bonding mode.
    - `slow`: LACP packets sent every 30 seconds (default IEEE 802.3ad behavior)
    - `fast`: LACP packets sent every 1 second for faster convergence
    Only applicable when using `802.3ad` bonding mode. Set to `null` for other bonding modes.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.lacp_rate == null || contains(["fast", "slow"], var.lacp_rate)
    error_message = "lacp_rate must be 'fast', 'slow', or null (only applicable for 802.3ad bonding mode)."
  }
}

variable "hash_policy" {
  description = <<EOT
    Hash algorithm used for packet distribution in load balancing bonding modes.
    Supported policies:
    - `layer2`: MAC addresses (simple but may cause uneven distribution)
    - `layer2+3`: MAC + IP addresses (better distribution for multiple subnets)
    - `layer3+4`: IP + port numbers (best for diverse traffic patterns)
    - `encap2+3`: Encapsulated MAC + IP (for VLAN environments)
    - `encap3+4`: Encapsulated IP + ports (for complex VLAN setups)
    Only applicable for modes that support load balancing (balance-xor, 802.3ad).
  EOT
  type        = string
  default     = null

  validation {
    condition = var.hash_policy == null || contains([
      "layer2",
      "layer2+3",
      "layer3+4",
      "encap2+3",
      "encap3+4"
    ], var.hash_policy)
    error_message = "hash_policy must be one of: layer2, layer2+3, layer3+4, encap2+3, encap3+4, or null."
  }
}

variable "primary" {
  description = <<EOT
    Primary interface name for active-backup bonding mode. This interface will be
    the preferred active interface when both links are available. Must be one of
    the interfaces specified in the `slaves` list. Example: `"eno1"`.
    Only applicable when using `active-backup` bonding mode.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.primary == null || length(trimspace(var.primary)) > 0
    error_message = "primary must be a non-empty interface name (must be one of the slaves interfaces) or null."
  }
}


###############################################################################
## VLANs
###############################################################################
variable "create_vlan" {
  description = <<EOT
    Flag to enable creation and maintenance of VLAN interfaces. When `true`,
    VLAN subinterfaces will be configured by directly editing `/etc/network/interfaces`
    and applying changes with `ifreload -a` via SSH. Defaults to `false`.
  EOT
  type        = bool
  default     = false
}

variable "interface" {
  description = <<EOT
    Parent interface name for the VLAN configuration. This should be an existing
    network interface on the Proxmox node (e.g., `eno1`, `bond0`, `vmbr0`).
    The VLAN will be created as a subinterface of this parent interface.
    Required when not using dot notation in the interface name.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.interface == null || length(trimspace(var.interface)) > 0
    error_message = "interface must be a non-empty string (e.g., 'eno1', 'bond0', 'vmbr0') or null."
  }
}

variable "vlan" {
  description = <<EOT
    VLAN ID number for network segmentation, following IEEE 802.1Q standard.
    Valid range is 1-4094 (VLAN 0 is reserved, 4095 is reserved for implementation use).
    Example: `100` for management VLAN, `200` for guest network.
    Required when not using dot notation in the interface name.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.vlan == null || (var.vlan >= 1 && var.vlan <= 4094)
    error_message = "vlan must be between 1 and 4094 (IEEE 802.1Q standard range) or null."
  }
}


###############################################################################
## Bridges
###############################################################################
variable "create_bridge" {
  description = <<EOT
    Flag to enable creation and maintenance of bridge interfaces. When `true`,
    bridge interfaces will be configured by directly editing `/etc/network/interfaces`
    and applying changes with `ifreload -a` via SSH. Defaults to `false`.
  EOT
  type        = bool
  default     = false
}

variable "ports" {
  description = <<EOT
    List of network interface names to attach to the bridge. Can include physical
    interfaces (e.g., `eno1`), bond interfaces (e.g., `bond0`), VLAN interfaces
    (e.g., `eno1.100`), or other network devices. Example: `["eno1", "bond0.200"]`.
    Set to `null` or empty list to create a bridge without attached ports.
  EOT
  type        = list(string)
  default     = null

  validation {
    condition = var.ports == null || alltrue([
      for port in var.ports : length(trimspace(port)) > 0
    ])
    error_message = "ports must contain only non-empty interface names (e.g., ['eno1', 'bond0', 'eno1.100']) or be null."
  }
}

variable "vids" {
  description = <<EOT
    VLAN IDs the bridge admits (`bridge-vids`), as a space-separated list of
    ids and hyphenated ranges, e.g. `2-4094`. Requires `vlan_aware = true`.
    Set to `null` to leave the node's default in place.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.vids == null || can(regex("^[0-9]+(-[0-9]+)?( [0-9]+(-[0-9]+)?)*$", var.vids))
    error_message = "vids must be null or a space-separated list of VLAN ids and ranges (e.g. '2-4094', '1 10-20 30')."
  }
}

variable "vlan_aware" {
  description = <<EOT
    Enable VLAN awareness for the bridge interface, allowing it to handle VLAN-tagged
    traffic from multiple VLANs simultaneously (trunk mode). When `true`, the bridge
    can process 802.1Q VLAN tags and route traffic between different VLANs.
    Set to `false` for access mode (single VLAN) bridges.
  EOT
  type        = bool
  default     = false
}
