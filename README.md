# homelab-iac

Terraform provisions Proxmox LXC guests. Ansible configures those guests using secrets encrypted with SOPS (age). Guest firewalls drop inbound traffic unless a rule opens a port. Guests are imported one at a time.

## Stack

| Layer | Tool |
| --- | --- |
| Hypervisor | Proxmox VE |
| Provisioning | Terraform (`bpg/proxmox`), state in Garage |
| Configuration | Ansible |
| Secrets | SOPS + age |
| Observability | Grafana, Prometheus, Loki, Tempo, Pyroscope, OpenTelemetry Collector |
| Edge | Caddy, TinyAuth (forward-auth), lldap |
| Workloads | Docker Compose, Renovate |

Apply from the CLI. Self-hosted GitHub runner after the stack is in Git.

## Layout

```
terraform/                 guests, firewall, remote state
terraform/modules/         reusable LXC definition
ansible/                   playbooks, roles, inventory
docker/monitoring/         observability compose project (CT 111)
docker/host/               stacks for the docker-host engine
```

Terraform owns the Proxmox object: VMID, resources, NIC, static IP, root SSH key, guest firewall. Ansible installs Docker and copies the matching `docker/` tree onto the guest; it only templates secrets and Prometheus scrape targets. Neither tool touches the other's side, so a drifting guest never causes a container rebuild.

## Inventory

| VMID | Address | Hostname | Role |
| --- | --- | --- | --- |
| 111 | 192.168.1.111 | monitoring | Observability stack |
| 112 | 192.168.1.112 | garage | Terraform state, S3 on :3900 |


## Observability

CT 111 runs Docker Engine and one Compose project. Grafana answers on `http://monitoring.antoinejosset.fr:3000`.

| Signal | Source |
| --- | --- |
| Host metrics | node-exporter on CT 111 |
| Container metrics | cAdvisor on CT 111 |
| Proxmox metrics | pve-exporter reading the API on 192.168.1.40 |
| Stack health | Loki, Tempo, Pyroscope and the collector scrape themselves |
| Metrics, logs, traces from applications | OTLP collector, ready to ingest |

## Commands

Age private key: `~/.config/sops/age/keys.txt`

```bash
task terraform -- plan
task terraform -- apply
task ansible -- playbooks/site.yml
task check
```

`task terraform` decrypts Garage S3 keys from SOPS, then runs Terraform in `terraform/`.

```bash
sops terraform/secrets.sops.yaml
sops ansible/inventory/group_vars/garage.sops.yml
sops ansible/inventory/group_vars/monitoring.sops.yml
```

## Done by hand

Terraform does not manage Proxmox users, tokens or DNS.

- Proxmox API user `terraform@pve` with `PVEAdmin` and `PVESysAdmin` on `/`, propagated.
- Proxmox API user `monitoring@pve` with a privilege-separated token, `PVEAuditor` on `/`. The token secret goes into `monitoring_pve_token_value`.
- Pi-hole A records for `garage` and `monitoring`.

Guest SSH uses `~/.ssh/jarvis_ed25519`.
