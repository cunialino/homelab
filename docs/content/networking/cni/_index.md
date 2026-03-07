+++
title = "CNI"
description = "Container networking with Cilium and eBPF"
weight = 1
sort_by = "weight"

[extra]
+++

[Cilium](https://cilium.io/) serves as my Container Network Interface (CNI) plugin for Kubernetes.
I chose Cilium primarily for its high-performance networking capabilities powered by eBPF,
along with robust security features essential for maintaining a secure and efficient homelab environment.

## Why I installed it

Traditional CNI solutions often rely on iptables for network policies, 
which can become a bottleneck at scale. Cilium leverages eBPF to provide:

- **High-performance networking**: Bypasses the kernel networking stack bottlenecks by using eBPF programs directly in the kernel
- **Advanced network policies**: Fine-grained control over inter-service communication with improved performance over iptables
- **Observability**: Built-in Hubble observability for monitoring, troubleshooting, and visualizing network traffic
- **Load balancing**: L4 load balancing with eBPF, offering better performance and scalability

## How I installed it

Cilium is configured via [cilium.yaml](https://github.com/cunialino/homelab/tree/main/cilium.yaml) in my homelab repository. The configuration enables:

- **BPF mode**: `kubeProxyReplacement: true` replaces kube-proxy with eBPF-based load balancing
- **Direct routing**: Auto-configured routes between nodes for efficient pod-to-pod communication
- **BPF masquerade disabled**: Set to `false` so Cilium doesn't manage traffic on wifi interfaces used for daily internet activities
- **Hubble observability**: Full stack enabled with metrics for DNS, drops, TCP flows, and ICMP
- **IPv4 CIDR**: Pod network uses `10.42.0.0/16` with native routing

## What it's used for

### 1. Inter-service communication control

Cilium enforces network policies at the kernel level using eBPF, allowing me to define which services can communicate with each other. This provides security without sacrificing performance.

### 2. Network visibility and troubleshooting

Hubble provides real-time visibility into cluster networking:
- View traffic flows between pods and services
- Detect dropped packets and understand why
- Monitor DNS queries across the cluster
- Visualize service dependencies

## References

- [Cilium official documentation](https://cilium.io/)
- [cilium.yaml configuration](https://github.com/cunialino/homelab/tree/main/cilium.yaml)
- [Hubble observability](https://cilium.io/learn/getting-to-know-hubble/)
