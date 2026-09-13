variable "node_name" {
  type = string
}

variable "container_ids" {
  description = "vm_id of each container, keyed by logical name (from the lxc module's output)"
  type        = map(number)
}

variable "lan_cidr" {
  type    = string
  default = "192.168.1.0/24"
}

variable "extra_rules" {
  description = "Optional per-container extra firewall rules, keyed by the same logical name used in container_ids"
  type = map(list(object({
    type    = string # "in" or "out"
    action  = string # "ACCEPT" or "DROP"
    proto   = optional(string, "tcp")
    dport   = optional(string, "")
    source  = optional(string, "")
    comment = optional(string, "")
  })))
  default = {}
}
