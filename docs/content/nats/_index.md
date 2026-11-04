+++
title = "NATS"
weight = 7
sort_by = "weight"
+++

[NATS](https://nats.io/) is a high-performance messaging system. It provides me a simple, secure, and performant way for applications to communicate.

## Configuration

I deploy NATS with [Flux](/cicd/flux/) as two `HelmRelease` objects in [infrastructure/controllers/nats/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/nats/).

### NATS Cluster

The NATS cluster ([helmrelease-cluster.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/controllers/nats/helmrelease-cluster.yaml)) is configured with:

*   **3 Replicas**: For high availability.
*   **JetStream Enabled**: With both memory and file-based storage.
*   **Persistent Storage**: JetStream uses a 5Gi Persistent Volume with the `longhorn-wdblack` storage class.
*   **Node Affinity**: Prefers nodes with the `nats-group: core-ha` label.
*   **Pod Anti-Affinity**: Ensures NATS pods are spread across different nodes for resilience.
*   **Resource Limits**: Configured with specific CPU and memory requests and limits.

### NACK (NATS Controller)

The NATS Controller ([helmrelease-nack.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/controllers/nats/helmrelease-nack.yaml)) manages my NATS cluster. It's configured to connect to the `nats-cluster` and has defined resource requests and limits.
