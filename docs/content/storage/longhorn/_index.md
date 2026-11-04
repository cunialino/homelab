+++
title = "Longhorn"
weight = 1
sort_by = "weight"
+++

[Longhorn](https://longhorn.io/) is a distributed block storage system for Kubernetes. It allows for highly available and persistent storage volumes, which are crucial for my stateful applications in my homelab.

## Configuration

I deploy Longhorn with [Flux](/cicd/flux/): the `HelmRelease` and its values in [infrastructure/controllers/longhorn/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/longhorn/), and the custom resources the operator acts on in [infrastructure/configs/longhorn/](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/longhorn/).

### Ingress

Access to the Longhorn UI is managed via an Ingress resource, which uses Tailscale for secure external access. The Ingress definition is located at [infrastructure/configs/longhorn/ingress.yaml](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/longhorn/ingress.yaml).

### Storage Classes

I define two main StorageClasses to cater to different performance and replication needs:

*   **`longhorn-wdblack`**: This storage class utilizes `wdblack` disks and is configured for 2 replicas. It's used for general-purpose persistent volumes. The configuration is in [infrastructure/configs/longhorn/wd_black.yaml](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/longhorn/wd_black.yaml).
*   **`longhorn-wdblack-freq`**: This storage class also uses `wdblack` disks with 2 replicas, but it additionally includes a recurring job for filesystem trimming (`trim-freq`). This is ideal for frequently accessed volumes that benefit from regular optimization. The configuration is in [infrastructure/configs/longhorn/wd_black_freq.yaml](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/longhorn/wd_black_freq.yaml).

### Recurring Jobs

I configure recurring jobs for filesystem trimming to run periodically, optimizing disk usage and performance.

*   **`trim-all`**: This job runs every 3 hours and performs a filesystem trim on all volumes. Defined in [infrastructure/configs/longhorn/maintenance.yaml](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/longhorn/maintenance.yaml).
*   **`trim-freq`**: This job runs hourly and is specifically associated with volumes provisioned by the `longhorn-wdblack-freq` storage class. Defined in [infrastructure/configs/longhorn/wd_black_freq.yaml](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/longhorn/wd_black_freq.yaml).

### Default Settings

I configure general Longhorn settings, such as `createDefaultDiskLabeledNodes`, `defaultDataPath`, and `backupTarget`, along with manager tolerations, inline in [infrastructure/controllers/longhorn/helmrelease.yaml](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/longhorn/helmrelease.yaml).