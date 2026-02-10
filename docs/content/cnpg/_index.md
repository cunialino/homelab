+++
title = "CloudNativePG"
weight = 6
sort_by = "weight"
+++

[CloudNativePG](https://cloudnative-pg.io/) is an open-source Kubernetes operator that manages PostgreSQL databases. It simplifies my deployment and lifecycle management of PostgreSQL clusters.

## Configuration

I deploy CloudNativePG via ArgoCD, with its configuration in [apps/cnpg.yaml](https://github.com/cunialino/homelab/tree/main/apps/cnpg.yaml) and specific PostgreSQL cluster and database configurations in [base/cnpg/](https://github.com/cunialino/homelab/tree/main/base/cnpg/).

### PostgreSQL Cluster

The `pg-cluster` ([base/cnpg/cluster.yaml](https://github.com/cunialino/homelab/tree/main/base/cnpg/cluster.yaml)) is a PostgreSQL cluster with 3 instances. It defines two managed roles:

*   **`risingwave`**: Used by the RisingWave application, with password managed by `rw-metastore-secret`.
*   **`vikunja`**: Used by the Vikunja application, with password managed by `vikunja` secret.

The cluster uses the `longhorn-wdblack` storage class for its 10Gi storage.

### Databases

I configure two databases within the `pg-cluster`:

*   **`risingwave`**: ([base/cnpg/risingwave.yaml](https://github.com/cunialino/homelab/tree/main/base/cnpg/risingwave.yaml)) A database named `risingwave` owned by the `risingwave` role. It includes the `bloom` extension.
*   **`vikunja`**: ([base/cnpg/vikunja.yaml](https://github.com/cunialino/homelab/tree/main/base/cnpg/vikunja.yaml)) A database named `vikunja` owned by the `vikunja` role. It also includes the `bloom` extension.

### External Secrets Integration

Passwords for the PostgreSQL roles (`risingwave` and `vikunja`) are managed by External Secrets:

*   **`rw-metastore-secret`**: ([base/cnpg/secret_risingwave.yaml](https://github.com/cunialino/homelab/tree/main/base/cnpg/secret_risingwave.yaml)) Fetches the `risingwave` password from Bitwarden.
*   **`vikunja`**: ([base/cnpg/secret_vikunja.yaml](https://github.com/cunialino/homelab/tree/main/base/cnpg/secret_vikunja.yaml)) Fetches the `vikunja` password from Bitwarden.
