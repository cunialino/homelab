+++
title = "Monitoring"
weight = 5
sort_by = "weight"
+++

Comprehensive monitoring is essential for understanding the health and performance of my homelab. I utilize the kube-prometheus-stack for metrics, Loki for logs, and Grafana for visualization.

## Configuration

I deploy the monitoring stack via ArgoCD as a multi-source application defined in [apps/monitoring.yaml](https://github.com/cunialino/homelab/tree/main/apps/monitoring.yaml) with four sources:
- **kube-prometheus-stack**: Prometheus, Grafana, and Alertmanager
- **Loki**: Log aggregation
- **Alloy**: Log and metric collection agent
- **base/monitoring/**: Custom resources (ingress, secrets)

Specific configurations are in [base/monitoring/](https://github.com/cunialino/homelab/tree/main/base/monitoring/).

### Grafana

Grafana provides powerful dashboards for visualizing my metrics.

*   **Ingress**: Access to the Grafana UI is managed via an Ingress resource ([base/monitoring/ingress.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/ingress.yaml)), using Tailscale for secure external access.
*   **Resources and Persistence**: Grafana is configured with resource requests/limits and uses a persistent volume with the `longhorn-wdblack` storage class for data persistence ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
*   **Loki Datasource**: Loki is pre-configured as an additional datasource, enabling log exploration directly within Grafana.
*   **Dashboards from Git**: the `grafana-sc-dashboard` sidecar ships enabled with `kube-prometheus-stack` and watches **all namespaces**
    for ConfigMaps labelled `grafana_dashboard=1` whose data keys end in `.json`. So a dashboard is just a manifest in
    [base/monitoring/](https://github.com/cunialino/homelab/tree/main/base/monitoring/) — no chart values change and no UI import.
    Referencing the provisioned datasource by its stable `uid: prometheus` (rather than by name) keeps the panels intact across reinstalls.
*   **elcunhalo LLM dashboard** ([base/monitoring/dashboard-elcunhalo.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/dashboard-elcunhalo.yaml),
    uid `elcunhalo-llm`): prefill and decode token throughput, prompt-cache hit rate, KV cache pressure, speculative-decode acceptance,
    preset residency and scrape coverage, plus GPU utilisation, power, clocks, temperatures and per-process memory.
    The quirks that shaped it:
    *   **Residency is `up`, not a gauge.** Each llama-swap preset is a scrape target on a fixed port (`job=llamacpp`, labelled
        `preset` and `unit`). That port only listens while the model is resident, so `up` *is* the residency signal and a cold preset
        refuses the connection rather than being woken — waking one with a scrape is what caused the original load → evict → reload loop.
    *   **No single label names a model.** Swap presets carry `preset=`, `gufo-llm.service` carries only its unit and `llama-decision`
        carries neither, so every per-model query derives `model` with `label_replace` per branch and unions the three.
    *   **Speed comes from the server's own gauges, never from a ratio of the counters.** `prompt_tokens_total` and
        `prompt_seconds_total` (and the `tokens_predicted_*` pair) do not advance in the same scrape — +3889 prompt tokens were observed
        with 0.19 busy-seconds, and +1109 decode tokens with 0.000 — so `rate(tokens) / rate(seconds)` is `+Inf` on ~87% of evaluation
        points and peaks near 3×10⁵ tok/s. `llamacpp:prompt_tokens_seconds` and `llamacpp:predicted_tokens_seconds` are the per-request
        PP/TG the server computes itself, available on every backend including the swap presets; they hold the last completed request
        until the next one, so read them as latest measured speed rather than a live average.
    *   **Ratio panels use a fixed window plus a volume floor, not `$__rate_interval`.** The prompt-cache hit rate moved to `[30m]` with a
        10k-token floor: at 15m the panel averaged 89% against a true 95.5% and showed seven spurious zeros, at 30m it averages 93% with
        three. Those three are real — each is 40k–175k computed prompt tokens with the cached counter unmoved, i.e. cold-cache prompts at
        the start of a session, which genuinely are a 0% hit. The floor matters because one small uncached prompt otherwise reports 0% for
        a server that hits its cache ~95% of the time. The same reasoning is why the panel spans every backend: swap presets produce almost
        no cached traffic, so a preset-only query is blank rather than low.
    *   **Some metrics only exist on some builds.** `llamacpp:kv_cache_usage_ratio` is exported by `gufo-llm` but not by the swap presets, so
        a missing line there is a metric gap, not an empty cache.
    *   **Coverage gates every number.** A preset that loads and unloads between scrapes is never collected at all, so per-model token
        totals are missing rather than approximate; *Coverage 30m* reports the share of scrapes that caught a resident preset.
    *   Textfile files are re-served even when nothing refreshes them, so *Collector health* tracks
        `time() - node_textfile_mtime_seconds` per file — the only way to tell a live reading from a stale one.
    *   **GTT, not VRAM.** The Strix Halo is an APU with no dedicated memory, so `amdgpu_vram_total_bytes` reports a fixed 1 GiB aperture.
        The model weights live in the GTT pool (133 GB), so memory pressure is `amdgpu_gtt_used_bytes / amdgpu_gtt_total_bytes`.
    *   **`llamacpp:prompt_tokens_total` counts only computed tokens.** Cache hits land in
        `llamacpp:prompt_tokens_cached_total`, so the hit rate is `cached / (cached + computed)` — dividing one by the other gives
        values in the hundreds, not percentages.

### Prometheus

Prometheus is responsible for collecting and storing metrics from my Kubernetes cluster.

*   **Retention**: Prometheus is configured to retain metrics for 10 days ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
*   **Storage**: It uses a 25Gi persistent volume with the `longhorn-wdblack` storage class for metric storage ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
*   **Remote Write**: The remote write receiver is enabled, allowing Alloy to forward node metrics directly to Prometheus.
*   **Remote Write From Outside The Cluster**: `prometheus-operated` is headless, so hosts that are not k3s nodes cannot reach it — they have neither
    cluster DNS nor a route into `10.42.0.0/16`. A dedicated `LoadBalancer` service ([base/monitoring/prometheus-lan-service.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/prometheus-lan-service.yaml))
    claims `192.168.0.203` from the [LAN IP pool](https://github.com/cunialino/homelab/tree/main/base/cilium/lb-ip-pool.yaml) and publishes `:9090`
    on the switch, restricted by `loadBalancerSourceRanges` to `192.168.0.0/24`.
    This is how **elcunhalo** (`192.168.0.6`, the Strix Halo LLM box) ships its metrics: its Alloy systemd unit scrapes a local
    `prometheus.exporter.unix` and remote writes to `http://192.168.0.203:9090/api/v1/write`, stamping `job="host-node-exporter"` and
    `instance="elcunhalo"` so it does not blend into the `job="node-exporter"` series produced by the in-cluster Alloy DaemonSet.

    **Note:** the Prometheus remote write receiver has no authentication of any kind, and this Service exposes the whole HTTP API — queries and
    `/api/v1/admin/*` included — not only `POST /api/v1/write`. The LAN source range is the only thing guarding it.

### Loki

[Loki](https://grafana.com/oss/loki/) is a log aggregation system that pairs with Grafana for log exploration.

*   **Mode**: Deployed as a `SingleBinary` (single replica, no separate backend/read/write components) ([base/monitoring/loki-values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/loki-values.yaml)).
*   **Storage**: Logs are stored on the filesystem with 40Gi persistent volume.
*   **Auth**: Authentication is disabled for internal cluster access.

### Alloy

[Grafana Alloy](https://grafana.com/docs/alloy/) is the collector agent that gathers logs and metrics within the cluster.

*   **Log Collection**: Reads systemd journal logs and Kubernetes pod logs from host mounts, and forwards them to Loki ([base/monitoring/alloy-values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/alloy-values.yaml)).
*   **Node Metrics**: Runs a node exporter via host mounts (`/proc`, `/sys`, `/`) and forwards the metrics to Prometheus via remote write.
*   **Host Access**: Runs with `hostPID: true` and mounts several host paths to access logs and system information.

### Alertmanager

Alertmanager handles alert routing and notification delivery.

*   **Status**: Enabled and configured with Telegram as the notification channel ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
*   **Routing**: Alerts are delivered via Telegram, with non-critical alerts (Watchdog, InfoInhibitor, info severity) routed to a null receiver.
*   **Credentials**: The Telegram bot token is managed externally via Bitwarden ([base/monitoring/secret_alertmanager.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/secret_alertmanager.yaml)).

### Custom Alert Rules

I define additional Prometheus alerting rules for common failure scenarios ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)):

*   **PodImagePullBackOff**: Fires when a pod is stuck in ImagePullBackOff for over 5 minutes.
*   **PodFrequentlyRestarting**: Fires when a pod restarts more than 5 times in an hour.
*   **PVCUsageWarning**: Fires when a PVC exceeds 80% capacity.
