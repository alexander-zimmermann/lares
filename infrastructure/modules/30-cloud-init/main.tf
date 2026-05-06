###############################################################################
## Provider packages
###############################################################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0"
    }
  }
}


###############################################################################
##  VM cloud-init configuration
###############################################################################
resource "proxmox_virtual_environment_file" "user_config" {
  count        = var.create_user_config ? 1 : 0
  content_type = "snippets"
  datastore_id = var.datastore
  node_name    = var.node

  source_raw {
    data = <<-EOF
      #cloud-config
      users:
        - default
%{for u in var.users~}
        - name: ${u.username}
          groups: ${jsonencode(u.groups)}
          shell: /bin/bash
%{if u.ssh_public_key != ""~}
          ssh_authorized_keys:
            - ${trimspace(file(pathexpand(u.ssh_public_key)))}
%{endif~}
          sudo: ALL=(ALL) NOPASSWD:ALL
%{if u.set_password~}
      chpasswd:
        list: |
          ${u.username}:${u.password}
        expire: false
%{endif~}
%{endfor~}
    EOF

    file_name = var.filename
  }
}

resource "proxmox_virtual_environment_file" "vendor_config" {
  count        = var.create_vendor_config ? 1 : 0
  content_type = "snippets"
  datastore_id = var.datastore
  node_name    = var.node

  source_raw {
    data = <<-EOF
      #cloud-config
%{if var.timezone != ""~}
      timezone: ${var.timezone}
%{endif~}
%{if var.locale != ""~}
      locale: ${var.locale}
%{endif~}
%{if length(var.apt) > 0~}
      apt: ${jsonencode(var.apt)}
%{endif~}
%{if length(var.disk_setup) > 0~}
      disk_setup: ${jsonencode(var.disk_setup)}
%{endif~}
%{if length(var.fs_setup) > 0~}
      fs_setup:
%{for fs in var.fs_setup~}
        - ${jsonencode(fs)}
%{endfor~}
%{endif~}
%{if length(var.bootcmd) > 0~}
      bootcmd:
%{for cmd in var.bootcmd~}
        - ${jsonencode(cmd)}
%{endfor~}
%{endif~}
%{if length(var.mounts) > 0~}
      mounts:
%{for m in var.mounts~}
        - ${jsonencode(m)}
%{endfor~}
%{endif~}
%{if length(var.mount_default_fields) > 0~}
      mount_default_fields: ${jsonencode(var.mount_default_fields)}
%{endif~}
%{if length(var.packages) > 0~}
      packages:
%{for p in var.packages~}
        - ${p}
%{endfor~}
%{endif~}
      package_update: ${var.package_update}
      package_upgrade: ${var.package_upgrade}
      package_reboot_if_required: ${var.package_reboot_if_required}
%{if length(var.snap) > 0~}
      snap:
        commands:
%{for cmd in try(var.snap.commands, [])~}
          - ${jsonencode(cmd)}
%{endfor~}
%{endif~}
%{if length(var.write_files) > 0~}
      write_files:
%{for f in var.write_files~}
        - path: ${f.path}
          content: ${try(f.trim, false) ? "|-" : "|"}
            ${indent(12, f.content)}
          permissions: "${f.permissions}"
          owner: "${f.owner}"
          encoding: "${f.encoding}"
          append: ${f.append}
          defer: ${f.defer}
%{endfor~}
%{endif~}
%{if length(var.runcmd) > 0~}
      runcmd:
%{for cmd in var.runcmd~}
        - ${jsonencode(cmd)}
%{endfor~}
%{endif~}
    EOF

    file_name = var.filename
  }
}

resource "proxmox_virtual_environment_file" "network_config" {
  count        = var.create_network_config ? 1 : 0
  content_type = "snippets"
  datastore_id = var.datastore
  node_name    = var.node

  source_raw {
    data = <<-EOF
      #cloud-config
      version: 2
      ethernets:
        match-all:
          match:
            name: "en*"
          dhcp4: ${var.dhcp4}
          dhcp6: ${var.dhcp6}
          accept-ra: ${var.accept_ra}
%{if length(var.ipv4_address) > 0 || length(var.ipv6_address) > 0~}
          addresses:
%{if length(var.ipv4_address) > 0~}
            - ${var.ipv4_address}
%{endif~}
%{if length(var.ipv6_address) > 0~}
            - ${var.ipv6_address}
%{endif~}
%{endif~}
%{if length(var.gateway4) > 0~}
          gateway4: ${var.gateway4}
%{endif~}
%{if length(var.gateway6) > 0~}
          gateway6: ${var.gateway6}
%{endif~}
%{if length(var.ipv4_address) > 0 || length(var.ipv6_address) > 0 || length(var.dns_search_domain) > 0~}
          nameservers:
%{if length(var.ipv4_address) > 0 || length(var.ipv6_address) > 0~}
            addresses: ${jsonencode(var.dns_servers)}
%{endif~}
%{if length(var.dns_search_domain) > 0~}
            search: ${jsonencode(var.dns_search_domain)}
%{endif~}
%{endif~}
    EOF

    file_name = var.filename
  }
}

resource "proxmox_virtual_environment_file" "meta_config" {
  count        = var.create_meta_config ? 1 : 0
  content_type = "snippets"
  datastore_id = var.datastore
  node_name    = var.node

  source_raw {
    data = <<-EOF
      #cloud-config
      local-hostname: ${var.hostname}
    EOF

    file_name = var.filename
  }
}
