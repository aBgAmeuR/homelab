resource "proxmox_virtual_environment_container" "garage" {
  node_name     = local.node_name
  vm_id         = local.garage.vmid
  description   = "Garage S3 (Managed by Terraform)"
  unprivileged  = true
  started       = true
  start_on_boot = true

  features {
    nesting = true
  }

  cpu {
    cores = local.garage.cores
  }

  memory {
    dedicated = local.garage.memory_mb
    swap      = local.garage.swap_mb
  }

  disk {
    datastore_id = local.garage.datastore
    size         = local.garage.disk_gb
  }

  operating_system {
    template_file_id = local.garage.ostemplate
    type             = "debian"
  }

  initialization {
    hostname = local.garage.hostname

    dns {
      domain  = local.garage.dns_domain
      servers = local.garage.dns_servers
    }

    ip_config {
      ipv4 {
        address = local.garage.ipv4
        gateway = local.garage.gateway
      }
    }

    user_account {
      keys = [local.ssh_public_key]
    }
  }

  network_interface {
    name     = "eth0"
    bridge   = local.garage.bridge
    firewall = true
  }

  wait_for_ip {
    ipv4 = true
    ipv6 = false
  }
}
