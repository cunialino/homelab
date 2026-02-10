+++
title = "NATS"
weight = 7
sort_by = "weight"
+++

[NATS](https://nats.io/) is a high-performance messaging system. It provides me a simple, secure, and performant way for applications to communicate.

## Configuration

I deploy NATS via ArgoCD, with its configuration in [apps/nats.yaml](https://github.com/cunialino/homelab/tree/main/apps/nats.yaml) and specific configurations in [base/nats/](https://github.com/cunialino/homelab/tree/main/base/nats/).

### NATS Cluster

The NATS cluster ([base/nats/cluster_values.yaml](https://github.com/cunialino/homelab/tree/main/base/nats/cluster_values.yaml)) is configured with:

*   **3 Replicas**: For high availability.
*   **JetStream Enabled**: With both memory and file-based storage.
*   **Persistent Storage**: JetStream uses a 5Gi Persistent Volume with the `longhorn-wdblack` storage class.
*   **Node Affinity**: Prefers nodes with the `nats-group: core-ha` label.
*   **Pod Anti-Affinity**: Ensures NATS pods are spread across different nodes for resilience.
*   **Resource Limits**: Configured with specific CPU and memory requests and limits.

### NACK (NATS Controller)

The NATS Controller ([base/nats/controller_values.yaml](https://github.com/cunialino/homelab/tree/main/base/nats/controller_values.yaml)) manages my NATS cluster. It's configured to connect to the `nats-cluster` and has defined resource requests and limits.
