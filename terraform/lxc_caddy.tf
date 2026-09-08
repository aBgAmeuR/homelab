module "caddy" {
  source = "./modules/lxc"

  node_name        = local.node_name
  vm_id            = 113
  hostname         = "caddy"
  description      = "Caddy reverse proxy (Managed by Terraform)"
  template_file_id = local.debian_template

  cores     = 1
  memory_mb = 256
  swap_mb   = 128
  disk_gb   = 4

  network         = local.network
  ipv4_address    = "192.168.1.113/24"
  ssh_public_keys = local.ssh_public_keys

  firewall_rules = [
    {
      comment = "SSH from remote-dev"
      source  = local.remote_dev_ipv4
      dport   = "22"
    },
    {
      comment = "HTTP from the LAN"
      source  = local.lan_cidr
      dport   = "80"
    },
    {
      comment = "HTTPS from the LAN"
      source  = local.lan_cidr
      dport   = "443"
    },
  ]

  depends_on = [
    proxmox_virtual_environment_cluster_firewall.lab,
    proxmox_node_firewall.pve,
  ]
}
