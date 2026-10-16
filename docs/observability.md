# Observability

CT 111 runs Docker Engine and one Compose project (`docker/monitoring`). Grafana answers on `https://monitoring.antoinejosset.fr` via Caddy (CT 113). Certificates come from Let's Encrypt using a Cloudflare DNS-01 challenge.

The guest firewall allows Grafana `:3000` from Caddy (`192.168.1.113`) only. The collector (`:4317`, `:4318` on `192.168.1.111`) accepts OTLP from the LAN (`192.168.1.0/24`).

## Signals

| Signal | Source |
| --- | --- |
| Host metrics | node-exporter on CT 111 and CT 115 |
| Container metrics | cAdvisor on CT 111 and CT 115 |
| Proxmox metrics | pve-exporter reading the API on 192.168.1.110 |
| Stack health | Loki, Tempo, Pyroscope and the collector scrape themselves |
| Harmony | OTLP from CT 115 to the collector on `:4318`. Traces in Tempo, logs in Loki, RED metrics from server spans |

## Harmony telemetry

Harmony sends traces, logs, and metrics to `http://192.168.1.111:4318` (`service.name=harmony`, `deployment.environment=production`). The collector keeps full traces in Tempo, logs in Loki, and builds request, error, and duration metrics from server spans.

The Grafana dashboard **Harmony** reads those metrics and logs. From a trace, Grafana opens the matching Loki lines. From a log line, it opens the Tempo trace.

## Dashboards

Provisioned from `docker/monitoring/grafana/dashboards/`: Docker cAdvisor, Harmony, Node Exporter Full, Proxmox VE.
