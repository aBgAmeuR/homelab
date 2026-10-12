# Harmony

CT 115 runs Harmony (`ghcr.io/abgameur/harmony:latest`) and `cloudflared` from `docker/host/harmony`.

## Runtime

The app listens on port 3000. `GET /health` returns `OK`. The image is distroless, so the compose healthcheck is `/app/server healthcheck` (same probe as the Dockerfile). `cloudflared` starts only after that check passes.

The port is published on the guest loopback (`127.0.0.1:3000`) so the playbook can wait on `http://127.0.0.1:3000/health`. No firewall rule opens it.

## Public access

Public access is a Cloudflare tunnel. The public hostname and the origin `http://harmony:3000` are set in Cloudflare Zero Trust. `TUNNEL_TOKEN` is part of `harmony_env` in `inventory/host_vars/docker.sops.yml`.

## Updates

A systemd timer on CT 115 pulls the Harmony image every 5 minutes.

## Deploy

```bash
task ansible -- playbooks/docker-host.yml --tags harmony
```

Telemetry is described in [Observability](observability.md).
