# Observability

CT 111 runs Docker Engine and one Compose project (`docker/monitoring`). Grafana answers on `https://monitoring.antoinejosset.fr` via Caddy (CT 113). Certificates come from Let's Encrypt using a Cloudflare DNS-01 challenge.

The guest firewall on CT 111 allows:

- Grafana `:3000` from Caddy (`192.168.1.113`) only.
- The collector (`:4317`, `:4318`) from the LAN (`192.168.1.0/24`), for OTLP.
- Prometheus remote write (`:9090`) and Loki push (`:3100`) from the guests and the Proxmox host only, for Alloy.

Every guest firewall accepts ping from CT 111, for the blackbox probes.

## Supervision agent

Every guest runs Grafana Alloy (role `alloy`, playbook `supervision.yml`), a Debian package pinned in the role defaults. It pushes metrics to Prometheus with remote write and logs to Loki, both on CT 111. Its UI listens on `127.0.0.1:12345` only.

| What | Detail |
| --- | --- |
| Host metrics | Built-in node-exporter, `job="node"`. Hardware collectors are off: an LXC has nothing to read there. `diskstats` is off too: inside an LXC it reports the host's block devices. Disk I/O per guest comes from pve-exporter, so the disk panels of **Node Exporter Full** stay empty for the guests |
| Services | `node_systemd_unit_state` for the units in `alloy_systemd_units`, plus `alloy.service` |
| Textfile | `*.prom` in `/var/lib/prometheus/node-exporter` (WireGuard peers on CT 118, container state on Docker hosts) |
| App metrics | `alloy_scrape_targets`, scraped on loopback: Blocky (`job="blocky"`), Garage admin API with its metrics token (`job="garage"`), cAdvisor on Docker hosts (`job="cadvisor"`) |
| Journal | Whole journal to Loki, labels `service_name` (the unit without `.service`, or the syslog identifier), `unit` and `level` (journald priority). Fields of JSON units (`alloy_journal_json_units`) become structured metadata |
| Containers | Docker hosts (`alloy_docker`): stdout and stderr of every container, `service_name` = Compose service, labels `container` and `compose_project`. Harmony is skipped (it sends its logs over OTLP). A timer writes `docker_container_info` and `docker_container_ok` (healthcheck status, exit code) every 30 s |

Every series and log line carries `instance` (the inventory name) and `vmid`. pve-exporter series get `vmid` too, from their `id`. `vmid` is the key that joins Proxmox, Alloy, probes and logs for one guest.

If CT 111 is unreachable, Alloy keeps metrics in its WAL and retries. Prometheus accepts samples up to 30 minutes late (`out_of_order_time_window`).

Group and host variables set what each guest reports: `alloy_systemd_units`, `alloy_scrape_targets`, `alloy_journal_json_units`, `alloy_docker`, `alloy_docker_logs_exclude`.

## Signals

| Signal | Source |
| --- | --- |
| Guest resources and uptime | pve-exporter reading the API on 192.168.1.110 (CPU, memory, root disk, network, uptime, start at boot) |
| Host metrics and services | Alloy on every guest |
| Container metrics | cAdvisor on CT 111 and CT 115, scraped by the local Alloy |
| Logs | Alloy on every guest (journal, containers). Harmony and its OTLP logs, see below |
| Probes | blackbox exporter on CT 111: ping every guest and the Proxmox host, HTTPS on every Caddy site's health path, a DNS query to Blocky |
| DNS | Blocky metrics and JSON log through Alloy on CT 116 (`service_name="blocky"`) |
| WireGuard | Peer handshakes and traffic on CT 118, through the textfile collector |
| Caddy | OTLP metrics and traces, pushed by Caddy to the collector |
| Stack health | Loki, Tempo, Pyroscope, the collector and blackbox scraped by Prometheus |
| Harmony | OTLP from CT 115 to the collector on `:4318`. Traces in Tempo, logs in Loki, RED metrics from server spans |

## Guest health

Probe targets are generated from the inventory (`roles/compose/templates/probes-*.yml.j2`). An HTTPS probe carries the `vmid` of the guest behind the site, so `files` and `docs` count for CT 115.

`docker/monitoring/rules/supervision.yml` records one series per guest and component, 1 when it passes:

| Component | Passes when |
| --- | --- |
| `running` | Proxmox runs the guest. Only for guests that start at boot |
| `agent` | Alloy pushed its host scrape in the last 5 minutes |
| `services` | Every unit in `alloy_systemd_units` is active |
| `containers` | Every container runs and is not unhealthy, or exited with code 0 |
| `endpoints` | Every local scrape (Blocky, Garage, cAdvisor) answers |
| `probes` | Ping, HTTPS and DNS probes of the guest succeed |

`vmid:health_component:bool{component=…}` holds each one and `vmid:health:min` the lowest. A guest only has the components that apply to it. Guests that do not start at boot (the stopped legacy CTs) have none. Availability over a period is `avg_over_time(vmid:health:min[30d])`.

## Catalog

The `compose` role also writes `/opt/monitoring/catalog.json`: the Proxmox node, every guest (vmid, address, description, groups, units, metric jobs, Docker or not) and every Caddy site with the guest behind it. It is generated from the inventory and holds no secret. Nothing mounts it yet; it is meant for Jarvis.

## Harmony telemetry

Harmony sends traces, logs, and metrics to `http://192.168.1.111:4318` (`service.name=harmony`, `deployment.environment=production`). The collector keeps full traces in Tempo, logs in Loki, and builds request, error, and duration metrics from server spans.

The Grafana dashboard **Harmony** reads those metrics and logs. From a trace, Grafana opens the matching Loki lines. From a log line, it opens the Tempo trace.

## Dashboards

Provisioned from `docker/monitoring/grafana/dashboards/`: Blocky, Docker cAdvisor, Guests, Harmony, Node Exporter Full, Proxmox VE, WireGuard.

**Guests** shows one guest at a time: health and its components, probes, uptime, 30-day availability, resources, filesystems, systemd units, containers and logs. The JSON is generated; edit it in Grafana and export it, or regenerate it.

## Deploy

The first rollout replaces node-exporter (CT 111, 115, 118) and the journald otelcol (CT 116) with Alloy. Run it in this order. Host, container and Blocky metrics pause from step 1 until step 4 is done:

1. `task tf:apply`: ports 9090 and 3100 on CT 111, ping on every guest, 512 MB and 8 GB for CT 113 and CT 118. The old 9100, 8080 and 4000 rules go away.
2. `task ansible -- playbooks/observability.yml`: Prometheus and Loki listen on `192.168.1.111`, blackbox, rules, probe targets, catalog. The node-exporter container goes away.
3. `task ansible -- playbooks/docker-host.yml --tags exporters`: the node-exporter container on CT 115 goes away, cAdvisor moves to loopback.
4. `task ansible -- playbooks/supervision.yml`: Alloy on every guest. It removes `prometheus-node-exporter` (CT 118) and `otelcol-contrib` (CT 116).

## Check

```bash
# On a guest: Alloy is up.
curl -s http://127.0.0.1:12345/-/ready
# On a guest (port 9090 only accepts the guests): health of every guest.
curl -s 'http://192.168.1.111:9090/api/v1/query?query=vmid:health:min'
```

From elsewhere, use the **Guests** dashboard or Grafana Explore.
