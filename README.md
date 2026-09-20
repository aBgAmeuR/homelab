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
| Edge | Caddy, TinyAuth (OIDC + forward-auth), lldap |
| Workloads | Docker Compose, Renovate |

Apply from the CLI.

## Layout

```
terraform/                 guests, firewall, remote state
terraform/modules/lxc      LXC containers from the tfvars map
terraform/modules/firewall cluster, node, and guest firewall
ansible/                   playbooks by domain, roles by software, inventory
docker/monitoring/         observability compose project (CT 111)
docker/host/               stacks for the docker-host engine
```

Terraform owns the Proxmox object: VMID, resources, NIC, static IP, root SSH key, guest firewall. Ansible configures software on the guest: Docker and the matching `docker/` tree on compose hosts, the Caddy package on CT 113, or the lldap and TinyAuth binaries on CT 114. Neither tool touches the other's side, so a drifting guest never causes a container rebuild.

## Inventory

| VMID | Address | Hostname | Role |
| --- | --- | --- | --- |
| 111 | 192.168.1.111 | monitoring | Observability stack |
| 112 | 192.168.1.112 | garage | Terraform state, S3 on :3900 |
| 113 | 192.168.1.113 | caddy | Reverse proxy |
| 114 | 192.168.1.114 | auth | lldap + TinyAuth |

## Observability

CT 111 runs Docker Engine and one Compose project. Grafana answers on `https://monitoring.antoinejosset.fr` via Caddy (CT 113). Certificates come from Let's Encrypt using a Cloudflare DNS-01 challenge. Guest firewall allows Grafana `:3000` from Caddy (`192.168.1.113`) only.

| Signal | Source |
| --- | --- |
| Host metrics | node-exporter on CT 111 |
| Container metrics | cAdvisor on CT 111 |
| Proxmox metrics | pve-exporter reading the API on 192.168.1.40 |
| Stack health | Loki, Tempo, Pyroscope and the collector scrape themselves |
| Metrics, logs, traces from applications | OTLP collector, ready to ingest |

## Auth

CT 114 runs lldap and TinyAuth as systemd units (no Docker). Caddy publishes `https://auth.antoinejosset.fr` to TinyAuth on `192.168.1.114:3000`. lldap listens on localhost only (LDAP 3890, UI 17170). Groups `admin` and `user` are homelab-wide. Grafana Generic OAuth uses TinyAuth as the OIDC issuer; the local Grafana `admin` password stays as break-glass.

Apply order: Terraform 114 → DNS → `playbooks/identity.yml` → `playbooks/edge.yml`. Grafana and TinyAuth share one OIDC client pair in `inventory/group_vars/all.sops.yml`.

Add user in lldap: [docs/add-user.md](docs/add-user.md).

## Commands

Age private key: `~/.config/sops/age/keys.txt`

```bash
task terraform -- plan
task terraform -- apply
task ansible -- playbooks/site.yml
task check
```

```bash
sops terraform/secrets.sops.yaml
sops ansible/inventory/group_vars/all.sops.yml
sops ansible/inventory/group_vars/garage_servers.sops.yml
sops ansible/inventory/group_vars/observability.sops.yml
sops ansible/inventory/group_vars/reverse_proxies.sops.yml
sops ansible/inventory/group_vars/identity_servers.sops.yml
```

## Done by hand

Terraform does not manage Proxmox users, tokens or DNS.

- Proxmox API user `terraform@pve` with `PVEAdmin` and `PVESysAdmin` on `/`, propagated.
- Proxmox API user `monitoring@pve` with a privilege-separated token, `PVEAuditor` on `/`. The token secret goes into `monitoring_pve_token_value`.
- Pi-hole A records for `garage`, `caddy`, and `monitoring`. `auth.antoinejosset.fr` must resolve to Caddy (`192.168.1.113`), not CT 114. Inventory host `auth` uses `ansible_host: 192.168.1.114`.
- After the identity playbook: lldap user ([docs/add-user.md](docs/add-user.md)).
- Cloudflare API token in `caddy_cloudflare_api_token`: Zone.Zone Read and Zone.DNS Edit on `antoinejosset.fr`.

Guest SSH uses `~/.ssh/jarvis_ed25519`.
