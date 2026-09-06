variable "node_name" {
  type        = string
  description = "Proxmox node hosting the container."
}

variable "vm_id" {
  type        = number
  description = "Container VMID."
}

variable "hostname" {
  type        = string
  description = "Guest hostname. Combined with the DNS domain it forms the FQDN."
}

variable "description" {
  type        = string
  description = "Description shown in the Proxmox UI."
  default     = "Managed by Terraform"
}

variable "template_file_id" {
  type        = string
  description = "OS template volume ID, for example local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst."
}

variable "unprivileged" {
  type        = bool
  description = "Run the container unprivileged."
  default     = true
}

variable "start_on_boot" {
  type        = bool
  description = "Start the container when the node boots."
  default     = true
}

variable "nesting" {
  type        = bool
  description = "Enable the nesting feature. Required to run Docker inside the container."
  default     = false
}

variable "cores" {
  type        = number
  description = "Number of CPU cores."
  default     = 1
}

variable "memory_mb" {
  type        = number
  description = "Memory in MiB."
  default     = 512
}

variable "swap_mb" {
  type        = number
  description = "Swap in MiB."
  default     = 256
}

variable "disk_gb" {
  type        = number
  description = "Root filesystem size in GiB."
  default     = 8
}

variable "datastore_id" {
  type        = string
  description = "Datastore holding the root filesystem."
  default     = "local-lvm"
}

variable "network" {
  type = object({
    bridge      = string
    gateway     = string
    dns_servers = list(string)
    dns_domain  = string
  })
  description = "Shared guest network settings."
}

variable "ipv4_address" {
  type        = string
  description = "Static IPv4 address in CIDR notation, for example 192.168.1.111/24."

  validation {
    condition     = can(cidrnetmask(var.ipv4_address))
    error_message = "ipv4_address must be an IPv4 address in CIDR notation."
  }
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Public keys injected as root, used by Ansible."
}

variable "firewall_input_policy" {
  type        = string
  description = "Default policy for inbound traffic."
  default     = "DROP"
}

variable "firewall_output_policy" {
  type        = string
  description = "Default policy for outbound traffic."
  default     = "ACCEPT"
}

variable "firewall_rules" {
  type = list(object({
    comment = string
    dport   = string
    source  = optional(string)
    proto   = optional(string, "tcp")
  }))
  description = "Inbound accept rules. Omit source to accept from anywhere."
  default     = []
}
