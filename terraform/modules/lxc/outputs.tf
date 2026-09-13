output "container_ids" {
  description = "vm_id of each container, keyed by logical name"
  value       = { for k, ct in proxmox_virtual_environment_container.this : k => ct.vm_id }
}

output "ip_addresses" {
  description = "IP address of each container, keyed by logical name"
  value       = { for k, v in var.containers : k => v.ip_address }
}
