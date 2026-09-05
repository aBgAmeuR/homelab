resource "proxmox_virtual_environment_cluster_firewall" "lab" {
  enabled        = true
  ebtables       = false
  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}

resource "proxmox_node_firewall" "pve" {
  node_name = local.node_name
  enabled   = true
  ndp       = false
  nftables  = false
}

resource "proxmox_virtual_environment_firewall_options" "garage" {
  node_name     = local.node_name
  container_id  = proxmox_virtual_environment_container.garage.vm_id
  enabled       = true
  dhcp          = false
  ndp           = false
  radv          = false
  input_policy  = "DROP"
  output_policy = "ACCEPT"

  depends_on = [
    proxmox_virtual_environment_cluster_firewall.lab,
    proxmox_node_firewall.pve,
  ]
}

resource "proxmox_virtual_environment_firewall_rules" "garage" {
  node_name    = local.node_name
  container_id = proxmox_virtual_environment_container.garage.vm_id

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH from remote-dev"
    source  = local.remote_dev_ipv4
    dport   = "22"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Garage S3 from remote-dev"
    source  = local.remote_dev_ipv4
    dport   = "3900"
    proto   = "tcp"
    log     = "nolog"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.garage]
}
