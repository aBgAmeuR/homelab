resource "proxmox_virtual_environment_container" "this" {
  for_each = var.containers

  node_name     = var.node_name
  vm_id         = each.value.vmid
  description   = each.value.description
  unprivileged  = each.value.unprivileged
  started       = true
  start_on_boot = each.value.start_on_boot

  features {
    nesting = each.value.nesting
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
    swap      = coalesce(each.value.swap, max(128, each.value.memory / 2))
  }

  disk {
    datastore_id = var.datastore_id
    size         = each.value.disk_size
  }

  operating_system {
    template_file_id = each.value.template
    type             = "debian"
  }

  initialization {
    hostname = each.value.hostname

    dns {
      domain  = "antoinejosset.fr"
      servers = ["192.168.1.41"]
    }

    ip_config {
      ipv4 {
        address = strcontains(each.value.ip_address, "/") ? each.value.ip_address : "${each.value.ip_address}/24"
        gateway = each.value.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  wait_for_ip {
    ipv4 = true
    ipv6 = false
  }
}
