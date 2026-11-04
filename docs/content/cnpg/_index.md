+++
title = "CloudNativePG"
weight = 6
sort_by = "weight"
+++

[CloudNativePG](https://cloudnative-pg.io/) is an open-source Kubernetes operator that manages PostgreSQL databases. It simplifies my deployment and lifecycle management of PostgreSQL clusters.

## Configuration

I deploy CloudNativePG with [Flux](/cicd/flux/): the operator in [infrastructure/controllers/cloudnative-pg/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/cloudnative-pg/) and everything the operator acts on — the cluster, its databases, the role credentials — in [infrastructure/configs/postgres/](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/postgres/).

### PostgreSQL Cluster

The `pg-cluster` ([cluster.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/cluster.yaml)) is a PostgreSQL cluster with 3 instances. It declares one managed role per application that connects to it: `vikunja`, `lakekeeper`, `oxicloud` and `openwebui`.

The cluster uses the `longhorn-wdblack` storage class for its 10Gi storage.

### Databases

Each application gets its own `Database` object, so the database appears and disappears with the application that owns it:

*   **`vikunja`**: ([vikunja.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/vikunja.yaml)) owned by the `vikunja` role, with the `bloom` extension.
*   **`lakekeeper`**: ([lakekeeper.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/lakekeeper.yaml)) owned by the `lakekeeper` role, with the `bloom` extension.
*   **`oxicloud`**: ([oxicloud.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/oxicloud.yaml)) owned by the `oxicloud` role.
*   **`openwebui`**: ([openwebui.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/openwebui.yaml)) owned by the `openwebui` role.

### Credentials

Role passwords are [SOPS-encrypted Secrets](/utils/secrets/) committed to Git, not values pulled from an external store at runtime:

*   **`lakekeeper-secret`**: ([role-secret-lakekeeper.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/role-secret-lakekeeper.yaml)) carries the `cnpg.io/reload` label so CNPG picks up a change.
*   **`oxicloud-db`**: ([role-secret-oxicloud.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/role-secret-oxicloud.yaml))
*   **`openwebui-db`**: ([role-secret-openwebui.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/role-secret-openwebui.yaml))

Vikunja is the odd one out on purpose: the Secret the operator reads and the Secret Vikunja itself reads ship in the same place, [apps/vikunja/base/](https://github.com/cunialino/homelab/tree/main/apps/vikunja/base/). Everywhere else the application's own copy lives with that application, which is why rotating a password touches two files.

## Monitoring

I monitor replication health with a `PrometheusRule` ([prometheusrule.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/prometheusrule.yaml)). It alerts on:

- **CNPGReplicationLagWarning**: Replica lag exceeds 60 seconds for 2 minutes
- **CNPGReplicationLagCritical**: Replica lag exceeds 5 minutes for 1 minute
- **CNPGReplicaFailing**: A replica is in recovery mode but its WAL receiver is down
