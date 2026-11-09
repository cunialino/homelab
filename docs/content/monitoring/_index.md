+++
title = "Monitoring"
weight = 5
sort_by = "weight"
+++

Comprehensive monitoring is essential for understanding the health and performance of my homelab. I utilize the kube-prometheus-stack for metrics, Loki for logs, and Grafana for visualization.

## Configuration

I deploy the monitoring stack with [Flux](/cicd/flux/) as three `HelmRelease` objects in [apps/monitoring/base/](https://github.com/cunialino/homelab/tree/main/apps/monitoring/base/), each with its values written inline:
- **`prometheus`** ([helmrelease-prometheus.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-prometheus.yaml)): kube-prometheus-stack — Prometheus, Grafana, and Alertmanager
- **`loki`** ([helmrelease-loki.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-loki.yaml)): Log aggregation
- **`alloy`** ([helmrelease-alloy.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-alloy.yaml)): Log and metric collection agent

The Ingress, the Alertmanager credentials and the extra dashboard are plain manifests in the same directory, synced by [clusters/homelab/apps/monitoring.yaml](https://github.com/cunialino/homelab/blob/main/clusters/homelab/apps/monitoring.yaml).

### Grafana

Grafana provides powerful dashboards for visualizing my metrics.

*   **Ingress**: Access to the Grafana UI is managed via an Ingress resource ([apps/monitoring/base/ingress.yaml](https://github.com/cunialino/homelab/tree/main/apps/monitoring/base/ingress.yaml)), using Tailscale for secure external access.
*   **Resources and Persistence**: Grafana is configured with resource requests/limits and uses a persistent volume with the `longhorn-wdblack` storage class for data persistence ([helmrelease-prometheus.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-prometheus.yaml)).
*   **Loki Datasource**: Loki is pre-configured as an additional datasource, enabling log exploration directly within Grafana.
*   **Dashboards from Git**: the `grafana-sc-dashboard` sidecar ships enabled with `kube-prometheus-stack` and watches **all namespaces**
    for ConfigMaps labelled `grafana_dashboard=1` whose data keys end in `.json`. So a dashboard is just a manifest in
    [apps/monitoring/base/](https://github.com/cunialino/homelab/tree/main/apps/monitoring/base/) — no chart values change and no UI import.
    Referencing the provisioned datasource by its stable `uid: prometheus` (rather than by name) keeps the panels intact across reinstalls.
*   **elcunhalo LLM dashboard** ([apps/monitoring/base/dashboard-elcunhalo.yaml](https://github.com/cunialino/homelab/tree/main/apps/monitoring/base/dashboard-elcunhalo.yaml),
    uid `elcunhalo-llm`): prefill and decode throughput per model — both delivered and per session — prompt-cache hit rate, KV cache pressure,
    speculative-decode acceptance, preset residency, scrape coverage and request backlog, plus GPU utilisation, power, clocks, temperatures and
    per-process memory.
    The quirks that shaped it:
    *   **Residency is `up`, not a gauge.** A llama-swap preset's port only listens while that model is resident, so `up` *is* the residency
        signal and a cold preset refuses the connection rather than being woken — waking one with a scrape is what caused the original
        load → evict → reload loop.
    *   **Two label dialects for the same thing.** Alloy scrapes most swap presets as `job=llamacpp` with `preset` and `unit`, and the
        `gufo-llm.service` preset as `job=gufo` with only `service`. Both are swap presets, so the residency panels select
        `job=~"llamacpp|gufo", service!="gufo-image.service"` and synthesise the missing `preset` label — before that the residency row showed
        1–4% coverage while the box was actually near 15%, because the backend carrying most of the traffic was filtered out.
        `llama-decision.service` is **not** swap-managed: it stays out of the residency row and appears as its own `model` elsewhere.
    *   **Two tok/s per model, both from counters.** **delivered** is `rate(tokens_total)` against wall clock, idle time included; **per session** is
        `increase(tokens) / increase(*_seconds_total)` — the server's own busy time. That counter accumulates per slot (`tokens_predicted_seconds_total` was
        measured advancing up to 2.58 s per wall second, and 0.886 s/s median with two sessions against 0.36 with one), so the ratio is each session's
        speed rather than the sum. gufo-llm over 24h measured **2.0 delivered against 46.5 per session**: the gap is idle time, not a slow model. Four
        stat panels give both numbers per model for whatever window is selected, and the prefill and decode series plot them together (per session solid,
        delivered dashed). A model that did no work produces no series rather than a zero, because a cold preset exposes no counters at all — an absent
        model is missing data, not a slow one. Per-session still cannot be split slot by slot: llama.cpp has no per-slot token counters and
        `n_busy_slots_per_decode` is missing from the gufo build.
    *   **Two agents cost each other speed, and the queue is invisible until you ask for it.** With `requests_processing` at 2, gufo-llm's per-session
        decode measured a 38.1 tok/s median against **53.0 solo** while delivered went the other way (12.1 → 32.7 median) — the drop is real contention,
        not a metric artifact, and decode barely scales: 51 tok/s solo max versus 57.5 with both slots busy, because generation is memory-bandwidth bound.
        Prefill is unaffected per session (970 → 958) since prompt batches serialise — `prompt_seconds_total` never exceeded 1.2 s/s. The concurrency line
        itself saturates at the slot count, so *Sessions and deferred requests* adds `requests_deferred`, the red dashed backlog: llama.cpp parks a request
        when `get_available_slot()` returns `nullptr` (`queue_tasks.defer(...)`) and exports the length of that parked queue. Over a week it was above 0 in
        232 scrapes, 231 of them with `requests_processing` pinned at 2, peaking at 8 waiting. A deferred request has not started, so it burns wall clock
        and contributes no busy seconds — per-session speed stays honest through a backlog while delivered thins out.
    *   **No single label names a model.** Swap presets carry `preset=`, `gufo-llm.service` carries only its unit and `llama-decision`
        carries neither, so every per-model query derives `model` with `label_replace` per branch and unions the three.
    *   **The speed gauges are now deliberately unused.** `prompt_tokens_seconds` / `predicted_tokens_seconds` hold the last completed request until
        the next one arrives, so elcunhalo reported 52.8 tok/s on gufo-llm through a day in which it generated almost nothing, and presets that never
        loaded reported nothing at all. The counter ratio they replace is sound but needs guarding: the token counter advances in scrapes the seconds
        counter does not, so an unguarded `rate(tokens) / rate(seconds)` reads `+Inf` on ~1% of evaluation points over a week and its finite tail reaches
        30194 tok/s for prefill against a 980 median. Writing it as `increase() / increase()` lets the guard read in seconds — prefill requires **10s of
        prompt evaluation** inside the window (peak 26544 → 5936 tok/s over a week, median unmoved), decode needs no floor since generation already runs
        long enough to average itself.
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

*   **Retention**: Prometheus is configured to retain metrics for 10 days ([helmrelease-prometheus.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-prometheus.yaml)).
*   **Storage**: It uses a 25Gi persistent volume with the `longhorn-wdblack` storage class for metric storage ([helmrelease-prometheus.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-prometheus.yaml)).
*   **Remote Write**: The remote write receiver is enabled, allowing Alloy to forward node metrics directly to Prometheus.
*   **Remote Write From Outside The Cluster**: `prometheus-operated` is headless, so hosts that are not k3s nodes cannot reach it — they have neither
    cluster DNS nor a route into `10.42.0.0/16`. A dedicated `LoadBalancer` service ([apps/monitoring/base/prometheus-lan-service.yaml](https://github.com/cunialino/homelab/tree/main/apps/monitoring/base/prometheus-lan-service.yaml))
    claims `192.168.0.203` from the [LAN IP pool](https://github.com/cunialino/homelab/blob/main/apps/cilium/base/ip-pool.yaml) and publishes `:9090`
    on the switch, restricted by `loadBalancerSourceRanges` to `192.168.0.0/24`.
    This is how **elcunhalo** (`192.168.0.6`, the Strix Halo LLM box) ships its metrics: its Alloy systemd unit scrapes a local
    `prometheus.exporter.unix` and remote writes to `http://192.168.0.203:9090/api/v1/write`, stamping `job="host-node-exporter"` and
    `instance="elcunhalo"` so it does not blend into the `job="node-exporter"` series produced by the in-cluster Alloy DaemonSet.

    **Note:** the Prometheus remote write receiver has no authentication of any kind, and this Service exposes the whole HTTP API — queries and
    `/api/v1/admin/*` included — not only `POST /api/v1/write`. The LAN source range is the only thing guarding it.

### Loki

[Loki](https://grafana.com/oss/loki/) is a log aggregation system that pairs with Grafana for log exploration.

*   **Mode**: Deployed as a `SingleBinary` (single replica, no separate backend/read/write components) ([helmrelease-loki.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-loki.yaml)).
*   **Storage**: Logs are stored on the filesystem with 40Gi persistent volume.
*   **Auth**: Authentication is disabled for internal cluster access.

### Alloy

[Grafana Alloy](https://grafana.com/docs/alloy/) is the collector agent that gathers logs and metrics within the cluster.

*   **Log Collection**: Reads systemd journal logs and Kubernetes pod logs from host mounts, and forwards them to Loki ([helmrelease-alloy.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-alloy.yaml)).
*   **Node Metrics**: Runs a node exporter via host mounts (`/proc`, `/sys`, `/`) and forwards the metrics to Prometheus via remote write.
*   **Host Access**: Runs with `hostPID: true` and mounts several host paths to access logs and system information.

### Alertmanager

Alertmanager handles alert routing and notification delivery.

*   **Status**: Enabled and configured with Telegram as the notification channel, in the values of [helmrelease-prometheus.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-prometheus.yaml).
*   **Routing**: Alerts are delivered via Telegram, with non-critical alerts (Watchdog, InfoInhibitor, info severity) routed to a null receiver.
*   **Credentials**: The Telegram bot token is a [SOPS-encrypted Secret](/utils/secrets/) in [secret-alertmanager.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/secret-alertmanager.yaml), mounted as a file Alertmanager reads at startup.

### Custom Alert Rules

I define additional Prometheus alerting rules for common failure scenarios ([helmrelease-prometheus.yaml](https://github.com/cunialino/homelab/blob/main/apps/monitoring/base/helmrelease-prometheus.yaml)):

*   **PodImagePullBackOff**: Fires when a pod is stuck in ImagePullBackOff for over 5 minutes.
*   **PodFrequentlyRestarting**: Fires when a pod restarts more than 5 times in an hour.
*   **PVCUsageWarning**: Fires when a PVC exceeds 80% capacity.
