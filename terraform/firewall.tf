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
