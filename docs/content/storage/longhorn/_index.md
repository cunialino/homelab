+++
title = "Longhorn"
weight = 1
sort_by = "weight"
+++

[Longhorn](https://longhorn.io/) is a distributed block storage system for Kubernetes. It allows for highly available and persistent storage volumes, which are crucial for my stateful applications in my homelab.

## Configuration

I deploy Longhorn via ArgoCD, and its configuration can be found in [apps/longhorn.yaml](https://github.com/cunialino/homelab/tree/main/apps/longhorn.yaml) and [base/longhorn/](https://github.com/cunialino/homelab/tree/main/base/longhorn/).

### Ingress

Access to the Longhorn UI is managed via an Ingress resource, which uses Tailscale for secure external access. The Ingress definition is located at [base/longhorn/ingress.yaml](https://github.com/cunialino/homelab/tree/main/base/longhorn/ingress.yaml).

### Storage Classes

I define two main StorageClasses to cater to different performance and replication needs:

*   **`longhorn-wdblack`**: This storage class utilizes `wdblack` disks and is configured for 2 replicas. It's used for general-purpose persistent volumes. The configuration is in [base/longhorn/wd_black.yaml](https://github.com/cunialino/homelab/tree/main/base/longhorn/wd_black.yaml).
*   **`longhorn-wdblack-freq`**: This storage class also uses `wdblack` disks with 2 replicas, but it additionally includes a recurring job for filesystem trimming (`trim-freq`). This is ideal for frequently accessed volumes that benefit from regular optimization. The configuration is in [base/longhorn/wd_black_freq.yaml](https://github.com/cunialino/homelab/tree/main/base/longhorn/wd_black_freq.yaml).

### Recurring Jobs

I configure recurring jobs for filesystem trimming to run periodically, optimizing disk usage and performance.

*   **`trim-all`**: This job runs every 3 hours and performs a filesystem trim on all volumes. Defined in [base/longhorn/maintanance.yaml](https://github.com/cunialino/homelab/tree/main/base/longhorn/maintanance.yaml).
*   **`trim-freq`**: This job runs hourly and is specifically associated with volumes provisioned by the `longhorn-wdblack-freq` storage class. Defined in [base/longhorn/wd_black_freq.yaml](https://github.com/cunialino/homelab/tree/main/base/longhorn/wd_black_freq.yaml).

### Default Settings

I configure general Longhorn settings, such as `createDefaultDiskLabeledNodes`, `defaultDataPath`, and `backupTarget`, along with manager tolerations, in [base/longhorn/values.yaml](https://github.com/cunialino/homelab/tree/main/base/longhorn/values.yaml).