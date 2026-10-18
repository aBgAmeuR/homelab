# Filestash

CT 115 runs Filestash (`machines/filestash`, pinned by digest) from `docker/host/filestash`. It replaces File Browser.

## Runtime

The app listens on port 8334. `GET /healthz` checks that the config is readable and sane.

The state (config, sqlite) is in `/var/lib/filestash/state`. Files are on the host dataset `/hdd/filebrowser`, mounted at `/mnt/filebrowser` in the CT and `/srv` in the container. The image runs as uid 1000.

## Access

Caddy publishes `https://files.antoinejosset.fr` behind TinyAuth `forward_auth`. Only `/healthz` skips it. Filestash has no OIDC in the free edition, so it does not know who is logged in.

Filestash uses the Passthrough middleware with the `direct` strategy. The login form submits itself and opens the `Files` connection: the local backend on `/srv/`, unlocked with `LOCAL_BACKEND_SECRET`. Every user who gets past TinyAuth shares that one space.

## Config

Filestash rewrites `config.json` on each start. The playbook merges the keys from `ansible/playbooks/templates/filestash-config.json.j2` into it and restarts the container only when one of them differs. A change made in `/admin` to one of those keys is reverted on the next run. Other settings stay as set in `/admin`.

`CONFIG_ENCRYPT=false` keeps the middleware params in clear text, so the comparison stays stable.

## Firewall

The guest firewall allows `:8334` from Caddy only. Filestash trusts any request that reaches it, so this rule is the only thing that keeps TinyAuth from being bypassed.

## Deploy

```bash
task tf:apply
task ansible -- playbooks/docker-host.yml --tags filestash
task ansible -- playbooks/dns.yml
task ansible -- playbooks/edge.yml
task ansible -- playbooks/identity.yml --tags tinyauth
```

Read the `/admin` password:

```bash
sops -d --extract '["filestash_admin_password"]' ansible/inventory/group_vars/all.sops.yml
```
