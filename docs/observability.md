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
| Textfile | `*.prom` in `/var/lib/prometheus/node-exporter`: pending apt upgrades on every guest, DHCP leases on CT 116, WireGuard peers on CT 118, container state on Docker hosts. `node_textfile_mtime_seconds{file=…}` tells when a file was last written |
| Updates | A timer writes `apt_upgrades_pending{origin,arch}` (security upgrades have `Debian-Security` in `origin`), `apt_autoremove_pending`, `apt_package_cache_timestamp_seconds` and `node_reboot_required` every 15 minutes, from `apt-get --just-print dist-upgrade`. `apt-daily.timer` refreshes the package lists once a day (`/etc/apt/apt.conf.d/10periodic`); it downloads and installs nothing |
| App metrics | `alloy_scrape_targets`, scraped on loopback: Blocky (`job="blocky"`), Garage admin API with its metrics token (`job="garage"`), cAdvisor on Docker hosts (`job="cadvisor"`) |
| Journal | Whole journal to Loki, labels `service_name` (the unit without `.service`, or the syslog identifier), `unit` and `level` (journald priority). Fields of JSON units (`alloy_journal_json_units`) become structured metadata |
| Containers | Docker hosts (`alloy_docker`): stdout and stderr of every container, `service_name` = Compose service, labels `container` and `compose_project`. Harmony is skipped (it sends its logs over OTLP). A timer writes `docker_container_info` and `docker_container_ok` (healthcheck status, exit code) every 30 s |

Every series and log line carries `instance` (the inventory name) and `vmid`. pve-exporter series get `vmid` too, from their `id`. `vmid` is the key that joins Proxmox, Alloy, probes and logs for one guest.

If CT 111 is unreachable, Alloy keeps metrics in its WAL and retries. Prometheus accepts samples up to 30 minutes late (`out_of_order_time_window`).

Group and host variables set what each guest reports: `alloy_systemd_units`, `alloy_scrape_targets`, `alloy_journal_json_units`, `alloy_docker`, `alloy_docker_logs_exclude`.

## Proxmox host

The Proxmox host is in the inventory as `pve` (group `pve_nodes`), apart from the guests (group `guests`). Only `supervision.yml` runs on it. It runs the same Alloy role with `alloy_node: true`:

| What | Detail |
| --- | --- |
| Labels | `instance="pve"` and no `vmid`, so it stays out of the guest health rules |
| Hardware | The hardware collectors are on: `node_hwmon_temp_celsius` (CPU, NVMe, NIC), `diskstats`, `nvme`, and ZFS with `node_zfs_zpool_state{zpool="hdd"}` |
| SMART | A timer runs `smart-metrics` every 5 minutes. It reads `smartctl --json` for every disk without waking a sleeping one and writes `smart_health_passed`, `smart_temperature_celsius`, `smart_power_on_hours`, the ATA error counters (`smart_ata_*`) and the NVMe wear and spare (`smart_nvme_*`). `smart_device_info` holds model and serial |
| Services | The PVE units (`pve-cluster`, `pvedaemon`, `pveproxy`, `pvestatd`, `pvescheduler`, `pve-firewall`), `zfs-zed`, `smartmontools`, `chrony` |
| Updates and journal | Same as the guests |

### Beyla

Alloy on the host also runs Beyla (`beyla.ebpf`, `alloy_beyla: true`). From the host kernel it sees the processes of every CT, so the apps need no instrumentation. eBPF needs privileges: on the host, a systemd drop-in (`alloy.service.d/root.conf`) runs Alloy as root. Guests keep the `alloy` user.

Beyla instruments the processes that listen on `alloy_beyla_open_ports` and pushes, per service (`job` and `service_name` = the executable or its `OTEL_SERVICE_NAME`):

- `http_server_request_duration_seconds` and `http_client_request_duration_seconds`, with route, method and status: request rate, errors and latency for Caddy, Grafana, TinyAuth, Filestash, AFFiNE, Harmony, Garage and Blocky;
- `db_client_operation_duration_seconds` for AFFiNE and Grafana.

`instance` is `<host>:<pid>`, so a restart starts new series. `pveproxy` (`:8006`) is left out: its workers change PID often. `beyla_instrumentation_errors_total{error_type="symbol_not_found"}` is expected for stripped Go binaries; Beyla falls back to kernel probes.

Beyla also writes the service graph (`traces_service_graph_*`, label `source="beyla"`), so Grafana's service map shows who calls whom: `caddy → grafana`, `caddy → filestash`, `caddy → server` (AFFiNE), `caddy → auth`, `caddy → pve.nas.local`, `monitoring → caddy`, and AFFiNE's database calls. Three settings make it work:

- **A span metrics feature.** Beyla only emits the service graph when a span metrics feature is on. `application_span` is used: its `traces_spanmetrics_*` names do not clash with the `traces_span_metrics_*` the central collector writes for Harmony.
- **Names for the guests.** Beyla resolves a peer IP with a reverse lookup (`name_resolver { sources = ["dns"] }`). The role writes a managed block at the top of the host's `/etc/hosts` that maps each guest address to its inventory name (`192.168.1.113 caddy`). It sits above the hand-written `192.168.1.113 auth.antoinejosset.fr` line, because a reverse lookup takes the first match. Without it, every peer is `incoming` or `outgoing`.
- **Relabelling** (`prometheus.relabel "beyla"`). Beyla also counts a client call to an instrumented guest as a virtual node named after the guest (`caddy → docker`). Those duplicates are dropped. `incoming → caddy` is dropped too: the central collector already reports `user → caddy`. Other unresolved callers become `user`.

A server is named after its process (`grafana`, `filestash`, `server` for AFFiNE), except TinyAuth, which Beyla names after its guest (`auth`).

## Signals

| Signal | Source |
| --- | --- |
| Guest resources and uptime | pve-exporter reading the API on 192.168.1.110 (CPU, memory, root disk, network, uptime, start at boot) |
| Host metrics and services | Alloy on every guest and on the Proxmox host |
| Proxmox host hardware | Temperatures, ZFS and SMART through Alloy on the host |
| Per-service HTTP and DB metrics | Beyla in Alloy on the Proxmox host |
| Container metrics | cAdvisor on CT 111 and CT 115, scraped by the local Alloy |
| Logs | Alloy on every guest (journal, containers). Harmony and its OTLP logs, see below |
| Probes | blackbox exporter on CT 111: ping every guest and the Proxmox host, HTTPS on every Caddy site's health path, a DNS query to Blocky |
| DNS | Blocky metrics and JSON log through Alloy on CT 116 (`service_name="blocky"`) |
| DHCP | `dnsmasq_leases` and `dnsmasq_lease_expiry_timestamp_seconds{mac,ip,hostname}` from the dnsmasq lease file on CT 116, every 30 s |
| Pending updates | apt on every guest, through the textfile collector |
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

## Alerting

Prometheus evaluates the rules in `docker/monitoring/rules/alerts.yml` and sends firing alerts to Alertmanager, in the same Compose project. Alertmanager has no receiver: nothing leaves the stack. It groups alerts by `alertname` and `vmid`, applies the inhibitions and holds the silences. Alerts are read in Grafana (**Alerting**, Alertmanager datasource) and, later, in Jarvis through the Alertmanager API. Alertmanager publishes no port.

| Severity | Meaning |
| --- | --- |
| `critical` | Something is down or about to break: a guest, a unit, a container, a probe, a disk |
| `warning` | Something degrades or needs a look: space, memory, temperature, SMART counters, a blind agent, a missing backup |
| `none` | `Watchdog` only. It always fires; if it is missing from Alertmanager, rules or delivery are broken |

| Group | Alerts |
| --- | --- |
| `guests` | `GuestDown`, `AgentSilent`, `ServiceDown`, `ContainerUnhealthy`, `EndpointDown` (critical for pve-exporter, which `GuestDown` depends on), `GuestMemoryHigh`, `OomKill` |
| `availability` | `ProbeFailed`, `CertificateExpiring` (warning under 14 days, critical under 7) |
| `storage` | `FilesystemAlmostFull` (20% and 10% free), `FilesystemFillingUp` (full within 24 hours), `ProxmoxStorageAlmostFull` (80% and 90%), `GuestNotBackedUp` (guests that start at boot) |
| `host` | `ZpoolUnhealthy`, `DiskFailing`, `DiskDegrading` (one alert per SMART `attribute`), `HardwareTemperatureHigh` (sensor max and crit; maxima above 150 °C are ignored as bogus), `DiskTemperatureHigh` (50 °C for a hard disk, 70 °C for an SSD) |
| `apps` | `BlockyBlockingDisabled`, `BlockyListsStale` |
| `meta` | `Watchdog`, `RuleEvaluationFailures` |

Updates and pending reboots raise no alert: they belong to the Maintenance view.

Fewer alerts for one cause:

- `GuestDown` inhibits every other alert with the same `vmid`.
- A critical alert inhibits the warning with the same name and target (`CertificateExpiring`, `FilesystemAlmostFull`, …).
- HTTPS probes carry `proxy_vmid`, the guest of the reverse proxy. `ProbeFailed` skips them while that guest is stopped or one of its units is down, so a Caddy outage shows as one `ServiceDown`, not five failed sites.

Silences: in Grafana, **Alerting → Silences**, with the Alertmanager datasource selected. They survive restarts (`/var/lib/monitoring/alertmanager`).

History: Prometheus keeps 90 days. The `ALERTS{alertstate="firing"}` series gives every firing period over that time.

Checks: `task check:alerting` runs `promtool` on the Prometheus config and the rules, the rule unit tests in `tests/prometheus/`, and `amtool check-config`. It needs `promtool` and `amtool` on the `PATH`, at the versions of the images in `compose.yaml`.

Deploy: `task ansible -- playbooks/observability.yml`.

## Catalog

The `compose` role also writes `/opt/monitoring/catalog.json`: the Proxmox node, every guest (vmid, address, description, groups, units, metric jobs, Docker or not) and every Caddy site with the guest behind it. It is generated from the inventory and holds no secret. Nothing mounts it yet; it is meant for Jarvis.

## Harmony telemetry

Harmony sends traces, logs, and metrics to `http://192.168.1.111:4318` (`service.name=harmony`, `deployment.environment=production`). The collector keeps full traces in Tempo, logs in Loki, and builds request, error, and duration metrics from server spans.

The collector also builds service graph metrics (`traces_service_graph_*`) from every trace it receives, Caddy's included. Grafana's Tempo datasource reads them from Prometheus for the service map. Edges between the guests come from Beyla (see [Beyla](#beyla)).

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
