locals {
  rules = {
    for name, id in var.container_ids :
    name => concat(
      [
        {
          type    = "in"
          action  = "ACCEPT"
          proto   = "tcp"
          dport   = "22"
          source  = var.lan_cidr
          comment = "SSH from the LAN"
        }
      ],
      lookup(var.extra_rules, name, [])
    )
  }
}

resource "proxmox_virtual_environment_cluster_firewall" "lab" {
  enabled        = true
  ebtables       = false
  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}

resource "proxmox_node_firewall" "pve" {
  node_name = var.node_name
  enabled   = true
  ndp       = false
  nftables  = false
}

resource "proxmox_virtual_environment_firewall_options" "this" {
  for_each = var.container_ids

  node_name     = var.node_name
  container_id  = each.value
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

resource "proxmox_virtual_environment_firewall_rules" "this" {
  for_each = var.container_ids

  node_name    = var.node_name
  container_id = each.value

  dynamic "rule" {
    for_each = local.rules[each.key]

    content {
      type    = rule.value.type
      action  = rule.value.action
      proto   = rule.value.proto
      dport   = rule.value.dport != "" ? rule.value.dport : null
      source  = rule.value.source != "" ? rule.value.source : null
      comment = rule.value.comment != "" ? rule.value.comment : null
      log     = "nolog"
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_options.this]
}
