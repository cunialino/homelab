+++
title = "Monitoring"
description = "Observability stack with Prometheus, Grafana, and alerting"
weight = 5
sort_by = "weight"

[extra]
+++

Comprehensive monitoring is essential for understanding the health and performance of the homelab. This section covers the observability stack and how to use it effectively.

## Overview

The monitoring stack is based on [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack), providing:

- **Metrics Collection**: Prometheus scrapes metrics from all cluster components
- **Visualization**: Grafana dashboards for metrics and logs
- **Alerting**: Alertmanager for notification routing (currently disabled)
- **Service Discovery**: Automatic detection of new services and pods

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Workloads                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   App    │  │  Cilium  │  │  Node    │  │  K8s     │    │
│  │ Exporter │  │ Metrics  │  │ Exporter │  │ Metrics  │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        └─────────────┴──────┬──────┴─────────────┘
                             │ scrape
┌────────────────────────────▼──────────────────────────────┐
│                     Prometheus                             │
│              (Metrics Storage & Query)                     │
└────────────────────────────┬──────────────────────────────┘
                             │ query
┌────────────────────────────▼──────────────────────────────┐
│                      Grafana                               │
│              (Visualization & Dashboards)                  │
└───────────────────────────────────────────────────────────┘
```

## Components

### Prometheus

Prometheus collects and stores time-series metrics:

- **Scraping**: Pulls metrics from exporters every 15-30 seconds
- **Storage**: 10-day retention with persistent volume
- **Querying**: PromQL for metrics analysis
- **Recording Rules**: Pre-aggregated metrics for performance

Configuration in [base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml):
- Retention: 10 days
- Storage: Longhorn persistent volume

### Grafana

Grafana provides visualization and alerting:

- **Dashboards**: Pre-configured Kubernetes and custom dashboards
- **Data Sources**: Prometheus, Loki (if enabled)
- **Access**: Via Ingress with Tailscale authentication
- **Persistence**: Configuration stored in Longhorn volume

Key dashboards available:
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Node Exporter / Nodes
- Cilium / Hubble

Access Grafana:
```bash
# Via port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Default credentials (if not changed)
# Username: admin
# Password: prom-operator
```

### Alertmanager

Alertmanager handles alert routing and notification (currently disabled):

- **Routing**: Send alerts to different receivers based on labels
- **Grouping**: Batch related alerts together
- **Inhibition**: Suppress notifications for dependent failures
- **Silencing**: Temporarily mute alerts

## Configuration

The monitoring stack is deployed via ArgoCD:

- **Application**: [apps/monitoring.yaml](https://github.com/cunialino/homelab/tree/main/apps/monitoring.yaml)
- **Values**: [base/monitoring/values.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/values.yaml)
- **Ingress**: [base/monitoring/ingress.yaml](https://github.com/cunialino/homelab/tree/main/base/monitoring/ingress.yaml)

### Custom Metrics

Applications can expose custom metrics:

```yaml
# Example ServiceMonitor for custom app
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-metrics
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

## Key Metrics to Watch

### Cluster Health

- **Node status**: `up{job="node-exporter"}`
- **Pod restarts**: `increase(kube_pod_container_status_restarts_total[1h])`
- **Resource usage**: `container_memory_usage_bytes`, `container_cpu_usage_seconds_total`

### Storage

- **Longhorn volume health**: `longhorn_volume_actual_size_bytes`
- **Disk usage**: `node_filesystem_avail_bytes`
- **PVC utilization**: `kubelet_volume_stats_available_bytes`

### Networking

- **Cilium drops**: `hubble_drop_total`
- **DNS latency**: `hubble_dns_query_total`
- **TCP connections**: `hubble_tcp_flags_total`

## Troubleshooting

### Common Issues

**Prometheus not scraping targets**:
```bash
# Check target status
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
```

**Grafana dashboards not loading**:
- Check datasource connectivity in Grafana UI
- Verify Prometheus is accessible from Grafana pod

**Missing metrics**:
- Ensure ServiceMonitor resources are created
- Check pod labels match ServiceMonitor selectors
- Verify metrics endpoint is accessible

## Related Documentation

- **[Networking](/networking)** - Cilium and Hubble metrics
- **[Storage](/storage)** - Longhorn storage metrics
- **[CI/CD](/cicd)** - GitOps pipeline monitoring
- **[External Access](/networking/external_access)** - Tailscale integration for secure access

## External Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
