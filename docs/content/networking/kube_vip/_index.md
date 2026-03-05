+++
title = "kube-vip"
description = "High availability load balancing for multi-node k3s clusters"
weight = 4
sort_by = "weight"

[extra]
+++

[kube-vip](https://kube-vip.io/) is an open-source project that provides load balancing capabilities for Kubernetes clusters. It simplifies building highly-available (HA) Kubernetes setups by offering a virtual IP (VIP) that can float between control plane nodes.

## Why I installed it

For my multi-node k3s cluster, I need a way to provide high availability without relying on external load balancers. kube-vip solves this by:

- **Virtual IP for cluster access**: Provides a stable IP address (`192.168.0.100`) that clients use to connect to the k3s API server, regardless of which node is currently active
- **Control plane load balancing**: Automatically distributes incoming traffic across all available control plane nodes
- **Automatic failover**: If a control plane node fails, kube-vip seamlessly moves the VIP to another healthy node

## How I installed it

I use a custom NixOS module that handles the complete setup of kube-vip. The module is configured in my [dotfiles](https://github.com/cunialino/dotfiles/blob/main/sys_mods/k3s/default.nix).

### Key configuration options:

- **Virtual IP** (`kube_vip_ip`): `192.168.0.100` - The floating IP for cluster access
- **RBAC setup**: On the bootstrap server, RBAC manifests are placed in `/var/lib/rancher/k3s/server/manifests/kube-vip-rbac.yaml` for cluster initialization
- **Static pods**: All nodes use static pods to accommodate varying network interface names across machines
- **Cluster init**: On the bootstrap server, enables `--cluster-init` for embedded etcd HA

## What it's used for

### 1. Cluster access stabilization

All clients (kubectl, CI/CD pipelines, applications) connect to `https://192.168.0.100:6443` instead of individual node IPs. This IP always routes to an active control plane node.

### 2. High availability failover

When a control plane node goes down:
- kube-vip detects the failure through leader election
- The VIP is transferred to another healthy node within seconds
- Client connections are re-established without manual intervention

## References

- [NixOS k3s module](https://github.com/cunialino/dotfiles/blob/main/sys_mods/k3s/default.nix) - My configuration
- [kube-vip official documentation](https://kube-vip.io/docs/)
