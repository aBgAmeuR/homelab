output "vm_id" {
  value       = proxmox_virtual_environment_container.this.vm_id
  description = "Container VMID."
}

output "hostname" {
  value       = var.hostname
  description = "Guest hostname."
}

output "fqdn" {
  value       = "${var.hostname}.${var.network.dns_domain}"
  description = "Guest FQDN, used by the Ansible inventory."
}

output "ipv4_address" {
  value       = split("/", var.ipv4_address)[0]
  description = "Guest IPv4 address without the prefix length."
}
