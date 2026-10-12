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
docker/host/               Compose projects on the docker host (CT 115)
```

Terraform owns the Proxmox object: VMID, resources, NIC, static IP, root SSH key, guest firewall. Ansible configures software on the guest: Docker and the matching `docker/` tree on compose hosts, the Caddy package on CT 113, or the lldap and TinyAuth binaries on CT 114. Neither tool touches the other's side, so a drifting guest never causes a container rebuild.

## Inventory

| VMID | Address | Hostname | Role |
| --- | --- | --- | --- |
| 111 | 192.168.1.111 | monitoring | Observability stack |
| 112 | 192.168.1.112 | garage | Terraform state, S3 on :3900 |
| 113 | 192.168.1.113 | caddy | Reverse proxy |
| 114 | 192.168.1.114 | auth | lldap + TinyAuth |
| 115 | 192.168.1.115 | docker | Compose host: Harmony, File Browser, AFFiNE, node-exporter, cAdvisor |

## Observability

CT 111 runs Docker Engine and one Compose project. Grafana answers on `https://monitoring.antoinejosset.fr` via Caddy (CT 113). Certificates come from Let's Encrypt using a Cloudflare DNS-01 challenge. The guest firewall allows Grafana `:3000` from Caddy (`192.168.1.113`) only. The collector (`:4317`, `:4318` on `192.168.1.111`) accepts OTLP from the LAN (`192.168.1.0/24`).

| Signal | Source |
| --- | --- |
| Host metrics | node-exporter on CT 111 and CT 115 |
| Container metrics | cAdvisor on CT 111 and CT 115 |
| Proxmox metrics | pve-exporter reading the API on 192.168.1.40 |
| Stack health | Loki, Tempo, Pyroscope and the collector scrape themselves |
| Harmony | OTLP from CT 115 to the collector on `:4318`. Traces in Tempo, logs in Loki, RED metrics from server spans |

Harmony sends traces, logs, and metrics to `http://192.168.1.111:4318` (`service.name=harmony`, `deployment.environment=production`). The collector keeps full traces in Tempo, logs in Loki, and builds request, error, and duration metrics from server spans. Grafana dashboard **Harmony** reads those metrics and logs. From a trace, Grafana opens the matching Loki lines; from a log line, it opens the Tempo trace.

## Harmony

CT 115 runs Harmony (`ghcr.io/abgameur/harmony:latest`) and `cloudflared` from `docker/host/harmony`. The app listens on port 3000. `GET /health` returns `OK`. The image is distroless, so the compose healthcheck is `/app/server healthcheck` (same probe as the Dockerfile). `cloudflared` starts only after that check passes. The port is published on the guest loopback (`127.0.0.1:3000`) so the playbook can wait on `http://127.0.0.1:3000/health`. No firewall rule opens it.

Public access is a Cloudflare tunnel. The public hostname and the origin `http://harmony:3000` are set in Cloudflare Zero Trust. `TUNNEL_TOKEN` is part of `harmony_env` in `inventory/host_vars/docker.sops.yml`. A systemd timer on CT 115 pulls the Harmony image every 5 minutes.

```bash
task ansible -- playbooks/docker-host.yml --tags harmony
```

## AFFiNE

CT 115 runs AFFiNE (`ghcr.io/toeverything/affine:stable`) with Postgres (`pgvector/pgvector:pg16`) and Redis. The app listens on port 3010. `GET /info` returns the server version. Postgres and Redis stay on the Compose network and are not published. Postgres uses trust authentication on that network only. Blobs are in `/var/lib/affine/storage`, the database in `/var/lib/affine/postgres`.

Caddy publishes `https://docs.antoinejosset.fr`. Login is TinyAuth OIDC. The issuer is `https://auth.antoinejosset.fr` and the redirect URI is `https://docs.antoinejosset.fr/oauth/callback`. `allowPrivateNetwork` is set because that issuer resolves to Caddy on the LAN. Password sign-up is off. The playbook creates `affine@antoinejosset.fr` once; that password account is break-glass. An OIDC sign-in creates a normal user. Promote that user from the admin panel.

The guest firewall allows `:3010` from Caddy only. Apply the firewall before the edge playbook, or the Caddy health check cannot reach AFFiNE.

```bash
task terraform -- apply
task ansible -- playbooks/identity.yml --tags tinyauth
task ansible -- playbooks/docker-host.yml --tags affine
task ansible -- playbooks/edge.yml
```

```bash
sops -d --extract '["affine_admin_password"]' ansible/inventory/group_vars/all.sops.yml
```

## Auth

CT 114 runs lldap and TinyAuth as systemd units (no Docker). Caddy publishes `https://auth.antoinejosset.fr` to TinyAuth on `192.168.1.114:3000`. lldap listens on localhost only (LDAP 3890, UI 17170). Groups `admin` and `user` are homelab-wide. Grafana Generic OAuth uses TinyAuth as the OIDC issuer; the local Grafana `admin` password stays as break-glass.

Apply order: Terraform 114 → DNS → `playbooks/identity.yml` → `playbooks/edge.yml`. Grafana, File Browser, Proxmox, and AFFiNE are TinyAuth OIDC clients. The client pairs live in `inventory/group_vars/all.sops.yml`.

Proxmox VE logs in through an OpenID realm named `tinyauth`. The browser must open `https://proxmox.antoinejosset.fr`: that origin is the redirect URI TinyAuth trusts. The issuer URL is `https://auth.antoinejosset.fr` with no path. Discovery then sends the browser to `https://auth.antoinejosset.fr/authorize`. `--username-claim username` maps the lldap uid (`preferred_username`) to `name@tinyauth`. There is no group mapping. `root@pam` stays the break-glass login. The node itself must resolve `auth.antoinejosset.fr` to Caddy (`192.168.1.113`). If it still reaches Nginx Proxy Manager on `192.168.1.100`, discovery comes from Authelia and the browser is sent to `/api/oidc/authorization`, which TinyAuth does not serve.

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
sops ansible/inventory/host_vars/docker.sops.yml
```

## Done by hand

Terraform does not manage Proxmox users, tokens or DNS.

- Proxmox API user `terraform@pve` with `PVEAdmin` and `PVESysAdmin` on `/`, propagated.
- Proxmox API user `monitoring@pve` with a privilege-separated token, `PVEAuditor` on `/`. The token secret goes into `monitoring_pve_token_value`.
- Proxmox OpenID realm, after `playbooks/identity.yml`. From the repo root, read the client pair, then on the Proxmox host:

```bash
sops -d --extract '["proxmox_oidc_client_id"]' ansible/inventory/group_vars/all.sops.yml
sops -d --extract '["proxmox_oidc_client_secret"]' ansible/inventory/group_vars/all.sops.yml
```

```bash
pveum realm add tinyauth --type openid \
  --issuer-url https://auth.antoinejosset.fr \
  --client-id CLIENT_ID \
  --client-key CLIENT_SECRET \
  --username-claim username \
  --autocreate 1 \
  --scopes 'email profile' \
  --comment 'TinyAuth'
```

`username-claim` cannot be changed later. The first login creates `name@tinyauth` with no role. Grant one on the host, for example `pveum acl modify / --users name@tinyauth --roles Administrator --propagate 1`.
- Pi-hole A records for `garage`, `caddy`, and `monitoring`. `auth.antoinejosset.fr`, `filebrowser.antoinejosset.fr`, and `docs.antoinejosset.fr` must resolve to Caddy (`192.168.1.113`), not to CT 114 or CT 115.
- On CT 115, as `root@pam`: mount point `mp0` with `/hdd/filebrowser,mp=/mnt/filebrowser`. The API token cannot set a host bind mount. Terraform ignores `mount_point` so a later apply does not remove it.
- On the Proxmox host, once: `chown 101000:101000 /hdd/filebrowser && chmod 755 /hdd/filebrowser`. The File Browser image writes as uid 1000, which an unprivileged CT maps to host uid 101000.
- After the identity playbook: lldap user ([docs/add-user.md](docs/add-user.md)).
- Cloudflare API token in `caddy_cloudflare_api_token`: Zone.Zone Read and Zone.DNS Edit on `antoinejosset.fr`.
- Cloudflare tunnel for Harmony: public hostname and origin `http://harmony:3000` in Zero Trust. The token stays in `harmony_env`.

Guest SSH uses `~/.ssh/jarvis_ed25519`.
