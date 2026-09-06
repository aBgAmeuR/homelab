locals {
  node_name = "pve"

  # Every LXC guest runs the same Debian release.
  debian_template = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  # Guests sit on a flat LAN. DNS is Pi-hole on CT 100.
  network = {
    bridge      = "vmbr0"
    gateway     = "192.168.1.1"
    dns_servers = ["192.168.1.41"]
    dns_domain  = "antoinejosset.fr"
  }

  # Firewall sources.
  lan_cidr        = "192.168.1.0/24"
  remote_dev_ipv4 = "192.168.1.74"

  ssh_public_keys = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
}
