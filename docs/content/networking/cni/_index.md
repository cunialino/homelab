+++
title = "CNI"
weight = 1
sort_by = "weight"
+++

As my Container Network Interface (CNI) plugin, I opted for [Cilium](https://cilium.io/). I chose Cilium primarily for its high-performance networking capabilities and robust security features, which are crucial for maintaining a secure and efficient homelab environment. Cilium leverages eBPF to provide advanced network policies, load balancing, and observability, giving me fine-grained control over inter-service communication.

## Configuration

The Cilium configuration is defined in [cilium.yaml](https://github.com/cunialino/homelab/tree/main/cilium.yaml). This file contains the Helm values used to configure Cilium with specific features for this cluster.

### Key Configuration Highlights

- **kubeProxyReplacement**: Enables eBPF-based kube-proxy replacement for better performance
- **bpf.masquerade**: Uses eBPF for IP masquerading instead of iptables
- **hubble.enabled**: Enables Hubble for network observability
- **hubble.metrics**: Collects DNS, drop, TCP, flow, and ICMP metrics
- **endpointRoutes.enabled**: Enables per-endpoint routing for better security
- **hostServices.enabled**: Enables host reachability services
- **externalIPs/nodePort**: Enables service exposure capabilities

> **Note**: View the complete configuration in [cilium.yaml](https://github.com/cunialino/homelab/tree/main/cilium.yaml) on GitHub.
