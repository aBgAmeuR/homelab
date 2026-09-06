module "monitoring" {
  source = "./modules/lxc"

  node_name        = local.node_name
  vm_id            = 111
  hostname         = "monitoring"
  description      = "Observability stack (Managed by Terraform)"
  template_file_id = local.debian_template

  cores     = 2
  memory_mb = 4096
  swap_mb   = 1024
  disk_gb   = 64
  nesting   = true

  network         = local.network
  ipv4_address    = "192.168.1.111/24"
  ssh_public_keys = local.ssh_public_keys

  firewall_rules = [
    {
      comment = "SSH from remote-dev"
      source  = local.remote_dev_ipv4
      dport   = "22"
    },
    {
      comment = "Grafana from the LAN"
      source  = local.lan_cidr
      dport   = "3000"
    },
  ]

  depends_on = [
    proxmox_virtual_environment_cluster_firewall.lab,
    proxmox_node_firewall.pve,
  ]
}
