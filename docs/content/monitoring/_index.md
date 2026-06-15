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

### Prometheus

Prometheus is responsible for collecting and storing metrics from my Kubernetes cluster.

*   **Retention**: Prometheus is configured to retain metrics for 10 days ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
*   **Storage**: It uses a 25Gi persistent volume with the `longhorn-wdblack` storage class for metric storage ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
*   **Remote Write**: The remote write receiver is enabled, allowing Alloy to forward node metrics directly to Prometheus.

### Loki

[Loki](https://grafana.com/oss/loki/) is a log aggregation system that pairs with Grafana for log exploration.

*   **Mode**: Deployed as a `SingleBinary` (single replica, no separate backend/read/write components) ([base/monitoring/loki-values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/loki-values.yaml)).
*   **Storage**: Logs are stored on the filesystem with a 15Gi persistent volume claim.
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
