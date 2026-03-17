+++
title = "CNI"
description = "Container networking with flannel and kube-router"
weight = 1
sort_by = "weight"

[extra]
+++

My Kubernetes cluster uses the k3s default CNI stack: [flannel](https://github.com/flannel-io/flannel) 
for pod networking and [kube-router](https://www.kube-router.io/) as a kube-proxy replacement.
This combination provides reliable, straightforward networking that works well across heterogeneous hardware in my homelab environment.

## Why I use it

Flannel provides a simple, reliable overlay network for pod communication using VXLAN or host-gateway modes.
Kube-router provides network policies enforcemnt.
Together they offer:

- **Simplicity**: Minimal configuration, works out of the box with k3s
- **Stability**: Proven solution that handles my mixed hardware reliably
- **Low overhead**: No eBPF complexity, standard Linux networking
- **Adequate performance**: Sufficient for homelab workloads without the tuning requirements of more advanced options

## How I use it

No additional configuration is needed—these components come pre-configured with k3s.
The pod network uses `10.42.0.0/16` with VXLAN overlay for cross-node communication.

## What it's used for

Flannel handles pod-to-pod networking across nodes, while kube-router manages service discovery and load balancing via BGP.
This setup ensures reliable connectivity between workloads without the complexity of advanced CNI features.

### Previous attempt: Cilium

I previously tried Cilium for its eBPF-powered networking and enhanced observability.
However, it caused older nodes in my cluster to freeze intermittently, likely due to eBPF compatibility issues or resource constraints on older hardware.
I switched back to k3s defaults for stability across all nodes.

## References

- [k3s networking documentation](https://docs.k3s.io/networking)
- [flannel](https://github.com/flannel-io/flannel)
- [kube-router](https://www.kube-router.io/)
