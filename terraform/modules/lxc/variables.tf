variable "node_name" {
  description = "Proxmox node to deploy containers on"
  type        = string
}

variable "containers" {
  description = "Map of LXC containers to create, keyed by a short logical name"
  type = map(object({
    vmid          = number
    hostname      = string
    ip_address    = string
    gateway       = string
    cores         = number
    memory        = number
    disk_size     = number # GB
    template      = string
    unprivileged  = optional(bool, true)
    start_on_boot = optional(bool, true)
    nesting       = optional(bool, false)
    swap          = optional(number)
    description   = optional(string, "Managed by Terraform")
  }))
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into every container"
  type        = list(string)
}

variable "datastore_id" {
  description = "Datastore used for container root disks"
  type        = string
  default     = "local-lvm"
}
