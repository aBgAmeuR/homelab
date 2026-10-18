# Bootstrap

Terraform does not manage Proxmox users, tokens or DNS. These steps are done by hand.

## Proxmox

- API user `terraform@pve` with `PVEAdmin` and `PVESysAdmin` on `/`, propagated.
- API user `monitoring@pve` with a privilege-separated token, `PVEAuditor` on `/`. The token secret goes into `monitoring_pve_token_value`.
- On CT 115, as `root@pam`: mount point `mp0` with `/hdd/filebrowser,mp=/mnt/filebrowser`. The API token cannot set a host bind mount. Terraform ignores `mount_point` so a later apply does not remove it.
- Turning `nesting` on for an existing CT fails with a 403 from the API token: the provider resends every feature flag, and only `root@pam` may change them. On the host: `pct set <vmid> --features nesting=1 && pct reboot <vmid>`, then `task tf:plan` shows no change. Debian 13 guests need nesting, or systemd-journald fails to start.
- On the Proxmox host, once: `chown 101000:101000 /hdd/filebrowser && chmod 755 /hdd/filebrowser`. The Filestash image writes as uid 1000, which an unprivileged CT maps to host uid 101000.

## OpenID realm

Run this after `playbooks/identity.yml`. From the repo root, read the client pair:

```bash
sops -d --extract '["proxmox_oidc_client_id"]' ansible/inventory/group_vars/all.sops.yml
sops -d --extract '["proxmox_oidc_client_secret"]' ansible/inventory/group_vars/all.sops.yml
```

Then on the Proxmox host:

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

`username-claim` cannot be changed later. The first login creates `name@tinyauth` with no role. Grant one on the host, for example:

```bash
pveum acl modify / --users name@tinyauth --roles Administrator --propagate 1
```

## DNS

Local records live in Blocky (`blocky_custom_dns`), see [DNS and DHCP](dns.md).

`auth.antoinejosset.fr`, `files.antoinejosset.fr`, and `docs.antoinejosset.fr` must resolve to Caddy (`192.168.1.113`), not to CT 114 or CT 115.

## Cloudflare

- API token in `caddy_cloudflare_api_token`: Zone.Zone Read and Zone.DNS Edit on `antoinejosset.fr`.
- Tunnel for Harmony: public hostname and origin `http://harmony:3000` in Zero Trust. The token stays in `harmony_env`.

## Identity

After the identity playbook, create the first lldap user: [Add a user](add-user.md).
