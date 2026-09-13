variable "proxmox_endpoint" {
  description = "e.g. https://192.168.1.40:8006/"
  type        = string
  default     = "https://192.168.1.40:8006/"
}

variable "proxmox_api_token" {
  description = "Source from the SOPS-decrypted secrets file, in terraform/.env"
  type        = string
  sensitive   = true
}

variable "node_name" {
  type    = string
  default = "pve"
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into every container. When empty, ~/.ssh/jarvis_ed25519.pub is used."
  type        = list(string)
  default     = []
}

variable "containers" {
  type = map(object({
    vmid          = number
    hostname      = string
    ip_address    = string
    gateway       = string
    cores         = number
    memory        = number
    disk_size     = number
    template      = string
    unprivileged  = optional(bool, true)
    start_on_boot = optional(bool, true)
    nesting       = optional(bool, false)
    swap          = optional(number)
    description   = optional(string, "Managed by Terraform")
  }))
}

variable "firewall_extra_rules" {
  type = map(list(object({
    type    = string
    action  = string
    proto   = optional(string, "tcp")
    dport   = optional(string, "")
    source  = optional(string, "")
    comment = optional(string, "")
  })))
  default = {}
}
