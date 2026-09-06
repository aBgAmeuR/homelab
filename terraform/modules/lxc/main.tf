resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  description   = var.description
  unprivileged  = var.unprivileged
  started       = true
  start_on_boot = var.start_on_boot

  features {
    nesting = var.nesting
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_gb
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  initialization {
    hostname = var.hostname

    dns {
      domain  = var.network.dns_domain
      servers = var.network.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.network.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  network_interface {
    name     = "eth0"
    bridge   = var.network.bridge
    firewall = true
  }

  wait_for_ip {
    ipv4 = true
    ipv6 = false
  }
}

resource "proxmox_virtual_environment_firewall_options" "this" {
  node_name     = var.node_name
  container_id  = proxmox_virtual_environment_container.this.vm_id
  enabled       = true
  dhcp          = false
  ndp           = false
  radv          = false
  input_policy  = var.firewall_input_policy
  output_policy = var.firewall_output_policy
}

resource "proxmox_virtual_environment_firewall_rules" "this" {
  node_name    = var.node_name
  container_id = proxmox_virtual_environment_container.this.vm_id

  dynamic "rule" {
    for_each = var.firewall_rules

    content {
      type    = "in"
      action  = "ACCEPT"
      comment = rule.value.comment
      source  = rule.value.source
      dport   = rule.value.dport
      proto   = rule.value.proto
      log     = "nolog"
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_options.this]
}
