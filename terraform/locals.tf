locals {
  node_name = "pve"

  remote_dev_ipv4 = "192.168.1.74"

  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  garage = {
    vmid        = 112
    hostname    = "garage"
    ipv4        = "192.168.1.112/24"
    gateway     = "192.168.1.1"
    dns_servers = ["192.168.1.41"]
    dns_domain  = "antoinejosset.fr"
    cores       = 1
    memory_mb   = 512
    swap_mb     = 256
    disk_gb     = 32
    datastore   = "local-lvm"
    bridge      = "vmbr0"
    ostemplate  = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  }
}
