+++
title = "Rust FS"
weight = 2
sort_by = "weight"
+++

[RustFS](https://github.com/rustfs/rustfs) is a lightweight file server application I deployed in my homelab. It provides me a simple way to serve files over HTTP.

## Configuration

I deploy RustFS via ArgoCD, with its configuration defined in [apps/rustfs.yaml](https://github.com/cunialino/homelab/tree/main/apps/rustfs.yaml) and the detailed Kubernetes resources in [base/rustfs/](https://github.com/cunialino/homelab/tree/main/base/rustfs/).

### Deployment

The deployment ([base/rustfs/deployment.yaml](https://github.com/cunialino/homelab/tree/main/base/rustfs/deployment.yaml)) configures a single replica of the RustFS application. It includes:

*   **Node Affinity**: Prefers `elcungem` or `elcunhp1` nodes for scheduling.
*   **Security Context**: Runs as a non-root user with a specific UID/GID.
*   **Environment Variables**: `RUSTFS_ACCESS_KEY` and `RUSTFS_SECRET_KEY` are sourced from a Kubernetes Secret named `rustfs-credentials`.
*   **Volume Mounts**: Mounts a persistent volume at `/data`.

### Service

A Kubernetes Service ([base/rustfs/service.yaml](https://github.com/cunialino/homelab/tree/main/base/rustfs/service.yaml)) exposes the RustFS application internally. It defines two ports:

*   **`api`**: Port 9000 (TCP) for the RustFS API.
*   **`ui`**: Port 9001 (TCP) for the RustFS web interface.

### Ingress

External access to RustFS is provided via an Ingress resource ([base/rustfs/ingress.yaml](https://github.com/cunialino/homelab/tree/main/base/rustfs/ingress.yaml)), which routes traffic through Tailscale. The Ingress exposes the UI port (9001) at the `/` path.

### Persistent Volume Claim

A Persistent Volume Claim ([base/rustfs/storage.yaml](https://github.com/cunialino/homelab/tree/main/base/rustfs/storage.yaml)) named `rustfs-pvc` is created with `ReadWriteOnce` access mode, using the `longhorn-wdblack-freq` StorageClass, and requests 100Gi of storage. This ensures data persistence for the RustFS application.