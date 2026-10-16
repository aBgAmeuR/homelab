# DNS and DHCP

CT 116 (`192.168.1.116`) runs Blocky and dnsmasq as native systemd services. It replaces Pi-hole (CT 100, `192.168.1.41`).

| Service | Role | Listens on |
| --- | --- | --- |
| Blocky | DNS for the LAN: blocking, cache, local records | `:53` UDP/TCP, `:4000` metrics |
| dnsmasq | DHCP, and the names of its DHCP clients for Blocky | `127.0.0.1:5353`, `:67` UDP when DHCP is on |

The guest firewall opens `:53` to the LAN, `:67` UDP from any source (DHCP requests come from `0.0.0.0`), and `:4000` to Prometheus (`192.168.1.111`) only. The Blocky API shares `:4000` and is not exposed anywhere else.

## Resolution

- Upstreams: `1.1.1.1` and `1.0.0.1`, plain UDP, strategy `parallel_best`.
- Blocking: HaGeZi Pro, one group for every client. Lists refresh every 4 hours, with an on-disk copy used when GitHub is unreachable.
- Local records: `blocky_custom_dns` in `ansible/inventory/group_vars/dns_servers.yml`. A name also covers its subdomains. There is no wildcard on `antoinejosset.fr`, so the Harmony hostname still resolves to Cloudflare.
- `*.lan` names (DHCP clients) and client names in metrics come from dnsmasq on `127.0.0.1:5353`.

DHCP announces `192.168.1.116` then `1.1.1.1`. A client that picks `1.1.1.1` gets no blocking and no local records. This trade-off is accepted so the network survives CT 116 being down.

## Observability

- Metrics: Prometheus job `blocky` scrapes `:4000`.
- Logs: Blocky writes JSON to journald. An `otelcol-contrib` on CT 116 (role `otelcol`) reads the unit, parses each line into attributes and sends OTLP to `192.168.1.111:4318`. In Loki the stream is `{service_name="blocky"}` and every JSON field is structured metadata, so no `| json` is needed:

  ```logql
  {service_name="blocky"} | prefix="queryLog" | response_type="BLOCKED"
  ```

- Dashboard **Blocky**: the upstream dashboard (Prometheus) without the API buttons, plus a Loki section with top domains, top blocked domains, slow upstream answers and a filterable query log. Loki keeps 14 days.

## Add a record or unblock a domain

Edit `ansible/inventory/group_vars/dns_servers.yml`:

```yaml
blocky_custom_dns:
  - { name: "new.{{ lab_domain }}", ip: 192.168.1.113 }

blocky_allowlist:
  - example.com
```

Then:

```bash
task ansible -- playbooks/dns.yml --tags dns
```

The configuration is checked with `blocky validate` before it is installed.

## DHCP

`dnsmasq_dhcp_enabled` stays `false` while Pi-hole serves DHCP. Range `192.168.1.20`-`192.168.1.100`, 12 h leases, no reservations: fixed hosts use static addresses outside the range.

## Check

```bash
dig @192.168.1.116 monitoring.antoinejosset.fr +short
dig @192.168.1.116 googlesyndication.com +short
```

The first returns `192.168.1.113`, the second `0.0.0.0`. HaGeZi Pro does not block `doubleclick.net` or `googleadservices.com` on purpose (Google Shopping links), so they are not a test of blocking.
