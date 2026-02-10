+++
title = "CNI"
weight = 1
sort_by = "weight"
+++

As my Container Network Interface (CNI) plugin, I opted for [Cilium](https://cilium.io/). I chose Cilium primarily for its high-performance networking capabilities and robust security features, which are crucial for maintaining a secure and efficient homelab environment. Cilium leverages eBPF to provide advanced network policies, load balancing, and observability, giving me fine-grained control over inter-service communication.

You can find the main Cilium installation configuration in [cilium.yaml](https://github.com/cunialino/homelab/tree/main/cilium.yaml).
