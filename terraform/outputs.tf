output "guests" {
  description = "Guests managed here, keyed by hostname. Mirrors the Ansible inventory."

  value = {
    for guest in [module.garage, module.monitoring, module.caddy] :
    guest.hostname => {
      vm_id        = guest.vm_id
      fqdn         = guest.fqdn
      ipv4_address = guest.ipv4_address
    }
  }
}
