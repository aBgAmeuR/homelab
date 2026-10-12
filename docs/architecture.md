# Architecture

Terraform provisions Proxmox LXC guests. Ansible configures the software on those guests, using secrets encrypted with SOPS (age). Guest firewalls drop inbound traffic unless a rule opens a port. Guests are imported one at a time.

## Layout

```
terraform/                 guests, firewall, remote state
terraform/modules/lxc      LXC containers from the tfvars map
terraform/modules/firewall cluster, node, and guest firewall
ansible/                   playbooks by domain, roles by software, inventory
docker/monitoring/         observability compose project (CT 111)
docker/host/               Compose projects on the docker host (CT 115)
docs/                      this documentation
```

## Who owns what

Terraform owns the Proxmox object: VMID, resources, NIC, static IP, root SSH key, guest firewall.

Ansible configures software on the guest: Docker and the matching `docker/` tree on compose hosts, the Caddy package on CT 113, or the lldap and TinyAuth binaries on CT 114.

Neither tool touches the other's side, so a drifting guest never causes a container rebuild.

## Inventory

| VMID | Address | Hostname | Role |
| --- | --- | --- | --- |
| 111 | 192.168.1.111 | monitoring | Observability stack |
| 112 | 192.168.1.112 | garage | Terraform state, S3 on :3900 |
| 113 | 192.168.1.113 | caddy | Reverse proxy |
| 114 | 192.168.1.114 | auth | lldap + TinyAuth |
| 115 | 192.168.1.115 | docker | Compose host: Harmony, File Browser, AFFiNE, node-exporter, cAdvisor |

## Playbooks

`ansible/playbooks/site.yml` imports the others in this order: baseline, docker, garage, identity, observability, docker-host, edge. Each playbook can also run alone, usually with `--tags`.

## Service pages

- [Observability](observability.md)
- [Auth](auth.md)
- [Harmony](harmony.md)
- [AFFiNE](affine.md)
- [Add a user](add-user.md)
- [Bootstrap](bootstrap.md): what is done by hand
- [Operations](operations.md): commands and secrets
