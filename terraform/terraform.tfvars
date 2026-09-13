node_name = "pve"

# Leave empty to inject ~/.ssh/jarvis_ed25519.pub
ssh_public_keys = []

containers = {
  monitoring = {
    vmid        = 111, hostname = "monitoring", ip_address = "192.168.1.111/24", gateway = "192.168.1.1"
    cores       = 2, memory = 4096, swap = 1024, disk_size = 64
    template    = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    nesting     = true
    description = "Observability stack (Managed by Terraform)"
  }
  garage = {
    vmid     = 112, hostname = "garage", ip_address = "192.168.1.112/24", gateway = "192.168.1.1"
    cores    = 1, memory = 512, swap = 256, disk_size = 32
    template = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    nesting  = true, description = "Garage S3 (Managed by Terraform)"
  }
  caddy = {
    vmid        = 113, hostname = "caddy", ip_address = "192.168.1.113/24", gateway = "192.168.1.1"
    cores       = 1, memory = 256, swap = 128, disk_size = 4
    template    = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    description = "Caddy reverse proxy (Managed by Terraform)"
  }
  auth = {
    vmid        = 114, hostname = "auth", ip_address = "192.168.1.114/24", gateway = "192.168.1.1"
    cores       = 1, memory = 512, swap = 256, disk_size = 8
    template    = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    description = "TinyAuth + lldap (Managed by Terraform)"
  }
}

firewall_extra_rules = {
  monitoring = [
    {
      type    = "in"
      action  = "ACCEPT"
      dport   = "3000"
      source  = "192.168.1.113"
      comment = "Grafana from Caddy"
    },
  ]

  garage = [
    {
      type    = "in"
      action  = "ACCEPT"
      dport   = "3900"
      source  = "192.168.1.74"
      comment = "Garage S3 from remote-dev"
    },
  ]

  caddy = [
    {
      type    = "in"
      action  = "ACCEPT"
      dport   = "80"
      source  = "192.168.1.0/24"
      comment = "HTTP from the LAN"
    },
    {
      type    = "in"
      action  = "ACCEPT"
      dport   = "443"
      source  = "192.168.1.0/24"
      comment = "HTTPS from the LAN"
    },
  ]

  auth = [
    {
      type    = "in"
      action  = "ACCEPT"
      dport   = "3000"
      source  = "192.168.1.113"
      comment = "TinyAuth from Caddy"
    },
  ]
}
