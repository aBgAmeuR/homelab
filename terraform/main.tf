locals {
  default_ssh_key_path = pathexpand("~/.ssh/jarvis_ed25519.pub")
  ssh_public_keys = (
    length(var.ssh_public_keys) > 0 ? var.ssh_public_keys :
    fileexists(local.default_ssh_key_path) ? [trimspace(file(local.default_ssh_key_path))] :
    []
  )
}

module "lxc" {
  source = "./modules/lxc"

  node_name       = var.node_name
  containers      = var.containers
  dns_servers     = var.dns_servers
  ssh_public_keys = local.ssh_public_keys
}

module "firewall" {
  source = "./modules/firewall"

  node_name     = var.node_name
  container_ids = module.lxc.container_ids
  probe_source  = "192.168.1.111"
  extra_rules   = var.firewall_extra_rules
}

resource "local_file" "guest_resources" {
  filename        = "${path.root}/../ansible/inventory/group_vars/guests.yml"
  file_permission = "0644"
  content = yamlencode({
    guest_resources = {
      for k, ct in var.containers : k => {
        cores     = ct.cores
        memory_mb = ct.memory
        swap_mb   = coalesce(ct.swap, max(128, ct.memory / 2))
        disk_gb   = ct.disk_size
      }
    }
  })
}
