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
  ssh_public_keys = local.ssh_public_keys
}

module "firewall" {
  source = "./modules/firewall"

  node_name     = var.node_name
  container_ids = module.lxc.container_ids
  extra_rules   = var.firewall_extra_rules
}
