+++
title = "KEDA"
weight = 8
sort_by = "weight"
+++

[KEDA](https://keda.sh/) is an event-driven autoscaler for Kubernetes. It scales workloads based on the number of events they need to process, instead of only on CPU and memory usage.

## Configuration

I deploy the KEDA operator via ArgoCD as a multi-source application defined in [apps/keda.yaml](https://github.com/cunialino/homelab/tree/main/apps/keda.yaml):

*   **kedacore/keda helm chart**: The operator, metrics server, and admission webhooks.
*   **base/keda/values.yaml**: Resource requests and limits for the operator, metrics server, and webhook pods.

The operator runs in the `keda` namespace and installs the KEDA CRDs (`ScaledObject`, `TriggerAuthentication`, etc.).

[ScaledObjects](https://keda.sh/docs/latest/concepts/scaling-deployments/) are defined where the workload they scale lives, so their exact location depends on the application repo. KEDA supports a large set of [scalers](https://keda.sh/docs/latest/scalers/) for queues, message brokers, databases, and more.

## Example

As an example, the [crypto-lakehouse](https://github.com/cunialino/crypto-lakehouse) repository scales its RisingWave compute StatefulSet based on the backlog of the NATS JetStream stream it consumes. The `ScaledObject` is at `deploy/base/risingwave/scaledobject.yaml` and uses the [`nats-jetstream` scaler](https://keda.sh/docs/latest/scalers/nats-jetstream/):

*   **Target**: The `risingwave-compute` StatefulSet in the `risingwave` namespace.
*   **Stream/Consumer**: Monitors the `risingwave_consumer` on the `tradesstream` JetStream stream.
*   **Endpoint**: `nats-cluster-headless.nats.svc.cluster.local:8222`, the NATS server monitoring endpoint (KEDA resolves the consumer leader across the 3-node cluster automatically).
*   **Bounds**: `minReplicaCount: 0` and `maxReplicaCount: 10`, with a 300s scale-down stabilization window to avoid flapping.