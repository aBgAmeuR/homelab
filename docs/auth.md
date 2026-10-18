# Auth

CT 114 runs lldap and TinyAuth as systemd units (no Docker). Caddy publishes `https://auth.antoinejosset.fr` to TinyAuth on `192.168.1.114:3000`. lldap listens on localhost only (LDAP 3890, UI 17170).

Groups `admin` and `user` are homelab-wide.

## Clients

Grafana, Proxmox, and AFFiNE are TinyAuth OIDC clients. The client pairs live in `inventory/group_vars/all.sops.yml`.

Filestash is behind Caddy `forward_auth` instead (`forward_auth: true` in `caddy_sites`). Caddy asks TinyAuth `/api/auth/caddy` on `192.168.1.114:3000` before each request, except for the site's `health_path`. See [Filestash](filestash.md).

Grafana uses Generic OAuth with TinyAuth as the OIDC issuer. The local Grafana `admin` password stays as break-glass.

## Apply order

Terraform 114, then DNS, then `playbooks/identity.yml`, then `playbooks/edge.yml`.

## Proxmox VE

Proxmox logs in through an OpenID realm named `tinyauth`. Creating the realm is a manual step, see [Bootstrap](bootstrap.md).

- The browser must open `https://proxmox.antoinejosset.fr`. That origin is the redirect URI TinyAuth trusts.
- The issuer URL is `https://auth.antoinejosset.fr` with no path. Discovery then sends the browser to `https://auth.antoinejosset.fr/authorize`.
- `--username-claim username` maps the lldap uid (`preferred_username`) to `name@tinyauth`.
- There is no group mapping. `root@pam` stays the break-glass login.
- The node itself must resolve `auth.antoinejosset.fr` to Caddy (`192.168.1.113`). If it still reaches Nginx Proxy Manager on `192.168.1.100`, discovery comes from Authelia and the browser is sent to `/api/oidc/authorization`, which TinyAuth does not serve.

## Users

See [Add a user](add-user.md).
