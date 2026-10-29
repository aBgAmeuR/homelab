# VPN

CT 118 (`192.168.1.118`) runs WireGuard with `wg-quick@wg0`. There is no web UI: peers live in `ansible/inventory/group_vars/vpn_servers.yml`. It replaces the WGDashboard container (CT 103, `192.168.1.56`).

| Setting | Value |
| --- | --- |
| Port | `16082` UDP. The box forwards it to `192.168.1.118` |
| Tunnel network | `10.0.0.0/24`, server `10.0.0.1` |
| Server key | `wireguard_private_key` in `ansible/inventory/group_vars/vpn_servers.sops.yml`, copied from CT 103 |
| Client DNS | `192.168.1.116` (Blocky): blocking and local records through the tunnel |

Tunnel traffic leaves CT 118 masqueraded to `192.168.1.118`, because the box has no route to `10.0.0.0/24`. The nftables table `ip wg0` is loaded by `wg-quick` on start and removed on stop. Whether a client sends all its traffic or only the LAN is its own `AllowedIPs`.

The guest firewall opens `16082` UDP from any source. Metrics leave with Alloy, so no metrics port is open.

## Add a peer

Needs `wireguard-tools` locally, and `qrencode` for a QR code.

```bash
WG_ENDPOINT=<public IP or host>:16082 task wg:peer -- laptop 10.0.0.3
```

The script prints the client configuration (all traffic by default; `WG_ALLOWED_IPS=192.168.1.0/24` for the LAN only) and a line for `wireguard_peers`. The client private key is shown once and stored nowhere. Add the line, then:

```bash
task ansible -- playbooks/vpn.yml --tags vpn
```

Peer changes go through `wg syncconf`: connected peers keep their session. Changing the address or the NAT rules restarts `wg0`.

## Remove a peer

Delete its line from `wireguard_peers` and run the playbook again.

## Observability

- Metrics: Alloy on CT 118 pushes host metrics as job `node`, `instance="vpn"`. A timer runs `wireguard-metrics` every 15 s and writes `wg show all dump` to the textfile collector: `wireguard_peer_last_handshake_seconds`, `wireguard_peer_receive_bytes_total` and `wireguard_peer_transmit_bytes_total`, labelled with the peer name from Ansible. `wg-quick@wg0` and the timer are the guest's services in the **Guests** dashboard.
- Dashboard **WireGuard**: tunnel state, connected peers (handshake in the last 3 minutes), traffic per peer, last handshake. Host metrics are in **Node Exporter Full**.
- No logs: kernel WireGuard writes nothing to the journal.

## Check

```bash
ssh root@192.168.1.118 wg show
ssh root@192.168.1.118 cat /var/lib/prometheus/node-exporter/wireguard.prom
```
