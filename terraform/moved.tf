# CT 112 predates the lxc module. These keep the existing objects in place
# instead of destroying and recreating the Terraform state backend.

moved {
  from = proxmox_virtual_environment_container.garage
  to   = module.garage.proxmox_virtual_environment_container.this
}

moved {
  from = proxmox_virtual_environment_firewall_options.garage
  to   = module.garage.proxmox_virtual_environment_firewall_options.this
}

moved {
  from = proxmox_virtual_environment_firewall_rules.garage
  to   = module.garage.proxmox_virtual_environment_firewall_rules.this
}
