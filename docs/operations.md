# Operations

## Secrets

Secrets are encrypted with SOPS and an age key. The private key is read from `~/.config/sops/age/keys.txt`. Guest SSH uses `~/.ssh/jarvis_ed25519`.

Edit an encrypted file:

```bash
sops terraform/secrets.sops.yaml
sops ansible/inventory/group_vars/all.sops.yml
sops ansible/inventory/group_vars/garage_servers.sops.yml
sops ansible/inventory/group_vars/observability.sops.yml
sops ansible/inventory/group_vars/reverse_proxies.sops.yml
sops ansible/inventory/group_vars/identity_servers.sops.yml
sops ansible/inventory/group_vars/vpn_servers.sops.yml
sops ansible/inventory/host_vars/docker.sops.yml
```

## Commands

Run `task` with no argument to list the available tasks.

```bash
task tf:init
task tf:plan
task tf:apply
task ansible -- playbooks/site.yml
task check
```

`task check` runs `terraform fmt -check`, `terraform validate`, and `ansible-playbook --syntax-check` on `playbooks/site.yml`.

Terraform state lives in Garage (S3 on CT 112). The `tf:*` tasks decrypt the S3 keys and the Proxmox API token with SOPS and pass them to Terraform as environment variables. Nothing is written to disk.

## Compose config changes

The `compose` role copies a project from `docker/` and runs `docker compose up --detach`. Compose recreates a service when its definition changes, `env_file` content included. It does not notice a bind-mounted file that changed on disk.

The role therefore fingerprints the project with `sha256sum` before and after the copy, reads the bind mounts from `docker compose config`, and runs `docker compose restart` on every service that mounts a changed file or a directory containing one. Editing `prometheus.yml` restarts Prometheus, and adding a dashboard restarts Grafana. Nothing else moves.
