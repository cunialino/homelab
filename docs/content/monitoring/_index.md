+++
title = "Monitoring"
weight = 5
sort_by = "weight"
+++

Comprehensive monitoring is essential for understanding the health and performance of my homelab. I utilize the kube-prometheus-stack to deploy Prometheus for metrics collection and Grafana for visualization.

## Configuration

I deploy the monitoring stack via ArgoCD, with its configuration defined in [apps/monitoring.yaml](https://github.com/cunialino/homelab/tree/main/apps/monitoring.yaml) and specific configurations in [base/monitoring/](https://github.com/cunialino/homelab/tree/main/base/monitoring/).

### Grafana

Grafana provides powerful dashboards for visualizing my metrics.

*   **Ingress**: Access to the Grafana UI is managed via an Ingress resource ([base/monitoring/ingress.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/ingress.yaml)), using Tailscale for secure external access.
*   **Resources and Persistence**: Grafana is configured with resource requests/limits and uses a persistent volume with the `longhorn-wdblack` storage class for data persistence ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).

### Prometheus

Prometheus is responsible for collecting and storing metrics from my Kubernetes cluster.

*   **Retention**: Prometheus is configured to retain metrics for 10 days ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
*   **Storage**: It uses a persistent volume with the `longhorn-wdblack` storage class for metric storage ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).

### Alertmanager

Alertmanager is currently disabled in my configuration ([base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)).
