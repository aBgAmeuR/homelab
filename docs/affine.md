# AFFiNE

CT 115 runs AFFiNE (`ghcr.io/toeverything/affine:stable`) with Postgres (`pgvector/pgvector:pg16`) and Redis, from `docker/host/affine`.

## Runtime

The app listens on port 3010. `GET /info` returns the server version.

Postgres and Redis stay on the Compose network and are not published. Postgres uses trust authentication on that network only.

Blobs are in `/var/lib/affine/storage`, the database in `/var/lib/affine/postgres`.

## Access

Caddy publishes `https://docs.antoinejosset.fr`. Login is TinyAuth OIDC. The issuer is `https://auth.antoinejosset.fr` and the redirect URI is `https://docs.antoinejosset.fr/oauth/callback`. `allowPrivateNetwork` is set because that issuer resolves to Caddy on the LAN.

Password sign-up is off. The playbook creates `affine@antoinejosset.fr` once, and that password account is break-glass. An OIDC sign-in creates a normal user. Promote that user from the admin panel.

## Firewall

The guest firewall allows `:3010` from Caddy only. Apply the firewall before the edge playbook, or the Caddy health check cannot reach AFFiNE.

## Deploy

```bash
task tf:apply
task ansible -- playbooks/identity.yml --tags tinyauth
task ansible -- playbooks/docker-host.yml --tags affine
task ansible -- playbooks/edge.yml
```

Read the break-glass password:

```bash
sops -d --extract '["affine_admin_password"]' ansible/inventory/group_vars/all.sops.yml
```
