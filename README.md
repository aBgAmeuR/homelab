# homelab-iac

Terraform provisions Proxmox LXC guests. Ansible configures those guests using secrets encrypted with SOPS (age). Guest firewalls drop inbound traffic unless a rule opens a port. Guests are imported one at a time.

## Stack

| Layer | Tool |
| --- | --- |
| Hypervisor | Proxmox VE |
| Provisioning | Terraform (`bpg/proxmox`), state in Garage |
| Configuration | Ansible |
| Secrets | SOPS + age |
| Edge | Caddy, TinyAuth (forward-auth), lldap |
| Workloads | Docker Compose, Renovate |

Apply from the CLI. Self-hosted GitHub runner after the stack is in Git.

## Layout

```
terraform/   guests, firewall, remote state
ansible/     playbooks, roles, inventory
```

## Inventory

| VMID | Address | Role |
| --- | --- | --- |
| 112 | 192.168.1.112 | Garage (Terraform state, S3 on :3900) |

## Commands

Age private key: `~/.config/sops/age/keys.txt`

```bash
task terraform -- plan
task terraform -- apply
task ansible -- playbooks/garage.yml
```

`task terraform` decrypts Garage S3 keys from SOPS, then runs Terraform in `terraform/`.

```bash
sops terraform/secrets.sops.yaml
sops ansible/inventory/group_vars/garage.sops.yml
```

Proxmox API user `terraform@pve` needs `PVEAdmin` and `PVESysAdmin` on `/` with propagate. Guest SSH uses `~/.ssh/jarvis_ed25519`.
