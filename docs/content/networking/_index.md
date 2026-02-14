+++
title = "Networking"
description = "Network configuration including Cilium CNI, Tailscale VPN, and external access"
weight = 3
sort_by = "weight"

[extra]
+++

Networking is the foundation that connects all cluster components. This section covers internal cluster networking, external access, and security policies.

## Overview

The networking stack provides:

- **Internal Communication**: High-performance pod-to-pod networking
- **Network Security**: Zero-trust policies with Cilium
- **External Access**: Secure VPN-based access via Tailscale
- **Service Discovery**: Kubernetes DNS and service mesh capabilities

## Components

### [Cilium CNI](/networking/cni)

[Cilium](https://cilium.io/) serves as the Container Network Interface (CNI), providing:

- **eBPF-based networking**: High-performance packet processing
- **Network policies**: Zero-trust security model
- **Observability**: Hubble for network flow visualization
- **Load balancing**: Kubernetes service proxy replacement
- **Encryption**: Optional WireGuard support

### [External Access](/networking/external_access)

External access is managed through:

- **[Tailscale](https://tailscale.com/)**: Private mesh VPN for secure remote access
- **Ingress resources**: Route external traffic to services
- **No public exposure**: Services are not exposed to the public internet

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        External Users                        │
└───────────────────────────┬─────────────────────────────────┘
                            │ Tailscale VPN
┌───────────────────────────▼─────────────────────────────────┐
│                      Tailscale Network                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Node 1     │  │   Node 2     │  │   Node N     │      │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │      │
│  │ │ Cilium   │◄─┼──┼►│ Cilium   │◄─┼──┼►│ Cilium   │ │      │
│  │ │ (eBPF)   │ │  │ │ (eBPF)   │ │  │ │ (eBPF)   │ │      │
│  │ └────┬─────┘ │  │ └────┬─────┘ │  │ └────┬─────┘ │      │
│  │      │       │  │      │       │  │      │       │      │
│  │   Pods       │  │   Pods       │  │   Pods       │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Security Model

The network follows a zero-trust security model:

1. **Default Deny**: All traffic is blocked by default
2. **Explicit Allow**: Network policies explicitly permit required communication
3. **Identity-Based**: Policies use workload identity, not IP addresses
4. **Encrypted**: Tailscale provides encrypted transport over public networks

## Network Policies

CiliumNetworkPolicies control traffic flow:

- **Ingress policies**: Define what can connect to a service
- **Egress policies**: Define what a service can connect to
- **Layer 7 filtering**: HTTP/gRPC-level rules
- **DNS-based rules**: Allow traffic to specific domains

Example use cases:
- Database pods only accept connections from application pods
- Services can only reach external APIs via explicit allow rules
- Monitoring stack has restricted access to metrics endpoints

## Observability

Network visibility is provided by:

- **Hubble**: Real-time network flow monitoring
- **Hubble UI**: Visual representation of traffic
- **Prometheus metrics**: Network policy violations, drops, latency

Access Hubble UI:
```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

## Related Documentation

- **[Security Practices](/introduction/security)** - Detailed security model and best practices
- **[Monitoring](/monitoring)** - Network metrics and dashboards
- **[CI/CD](/cicd)** - How networking integrates with deployment pipelines
