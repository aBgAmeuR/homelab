variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint."
  default     = "https://192.168.1.40:8006/"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the ed25519 public key injected as root on LXCs."
  default     = "~/.ssh/jarvis_ed25519.pub"
}
