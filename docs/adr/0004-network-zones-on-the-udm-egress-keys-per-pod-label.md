# Network zones live on the UDM; the cluster hands out egress keys per pod label

The house is segmented by device class into VLANs on the UDM, and the
UDM firewalls between them: Internal (clients and media), Infrastructure
(UniFi gear, Proxmox, PBS, Omni, UNAS), IoT LAN (devices that control the
house and cannot defend themselves), IoT Cloud (appliances that talk to a
vendor cloud), Security (cameras and door station on unpluggable outdoor
ports), Kubernetes (Talos nodes, egress IPs, LoadBalancer pool). VLAN id
equals the third octet of the subnet, and every VLAN follows one address
convention: `.1` gateway, `.2`–`.49` fixed addresses, `.50`–`.199` DHCP,
`.200`–`.254` special purpose (in VLAN 10 the LoadBalancer pool).

The UDM sees the cluster only as node IPs and cannot tell pods apart, so
it is given exactly two exceptions: the egress IPs `.2` and `.3`, one
secondary address per gateway worker. Cilium's egress gateway decides,
from pod label and destination CIDR, which traffic leaves with one of
them: `egress-infra`, `egress-iot`, `egress-security`. A pod without the
label leaves with the node IP and is dropped at the zone border; a pod
with one label still reaches the other zones with the node IP and is
dropped there. The UDM therefore holds one rule with ports per zone for
the pair and no knowledge of pods.

A Cilium network policy exists only where the UDM is blind: the four LLM
agents (`role=agent`) are caged inside the cluster and towards the
internet by FQDN. No other namespace carries a network policy.

The LoadBalancer pool stays a BGP-routed prefix and every LAN client
reaches every LB IP directly; `*.zimmermann.sh` keeps going through
Cloudflare and Traefik. Dual-homing is a feature, not an artefact.

## Considered options

- **Second Traefik in a DMZ VLAN, one IngressRoute per domain** (#683):
  a VLAN sits on the node, not on the pod; a LoadBalancer IP in a DMZ
  subnet is only the door in, the pod behind it still leaves with the
  node IP. Doubles every route and certificate for no isolation.
- **Default-deny Cilium policies in every namespace** (#685 as written):
  every app needs ingress and egress rules, every chart bump can break a
  scrape silently (drop, not refuse), and the UDM would still see one
  flat cluster. Isolation the firewall can enforce belongs on the
  firewall.
- **Announce the PodCIDR via BGP and drop masquerading** so the UDM sees
  pod IPs: pod IPs are allocated per node, not per app, so the UDM still
  could not tell an exporter from an agent; only multi-pool IPAM would,
  and that rebuilds addressing on a running cluster.
- **One IoT VLAN for everything**: puts a cloud-connected appliance with
  foreign firmware on the same L2 segment as the KNX IP interface, which
  accepts telegrams without authentication.
- **Alarm system next to the cameras**: the camera ports are the ones
  anyone can unplug from the house wall; that zone is the least trusted,
  not the most.
