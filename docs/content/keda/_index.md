+++
title = "KEDA"
weight = 8
sort_by = "weight"
+++

[KEDA](https://keda.sh/) is an event-driven autoscaler for Kubernetes. It scales workloads based on the number of events they need to process, instead of only on CPU and memory usage.

## Configuration

I deploy KEDA with [Flux](/cicd/flux/) from [infrastructure/controllers/keda/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/keda/), as two `HelmRelease` objects with their values written inline:

*   **`keda`** ([helmrelease.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/controllers/keda/helmrelease.yaml)): The operator, metrics server, and admission webhooks.
*   **`keda-add-ons-http`** ([helmrelease-http.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/controllers/keda/helmrelease-http.yaml)): The HTTP add-on, which scales on request rate through an interceptor instead of on queue depth.

The operator runs in the `keda` namespace and installs the KEDA CRDs (`ScaledObject`, `TriggerAuthentication`, etc.).

[ScaledObjects](https://keda.sh/docs/latest/concepts/scaling-deployments/) are defined where the workload they scale lives, so their exact location depends on the application repo. KEDA supports a large set of [scalers](https://keda.sh/docs/latest/scalers/) for queues, message brokers, databases, and more.

## Example

As an example, the [myai](https://github.com/cunialino/myai) repository keeps its two llama.cpp models scaled to nothing between requests. The `ScaledObject`s live next to the workloads they scale, in `clusters/homelab/apps/graphiti/`:

*   **Targets**: The `llamacpp-graphiti` and `llamacpp-embed` Deployments in the `graphiti` namespace.
*   **Scaler**: [`external-push`](https://keda.sh/docs/latest/scalers/external-push/), fed by the KEDA HTTP add-on's interceptor, so a model wakes up on the request that needs it.
*   **Bounds**: `minReplicaCount: 0` and `maxReplicaCount: 1` — one model of each kind is all the RAM allows, and nothing runs while idle.

Because the add-on's scaler runs as its own ServiceAccount in the `keda` namespace while the workloads live in `graphiti`, that directory also carries `keda-rbac-fix.yaml`: a `ClusterRole` and `ClusterRoleBinding` granting the scaler rights over the namespace it scales.