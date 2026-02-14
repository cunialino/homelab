+++
title = "Introduction"
description = "Welcome to my homelab documentation - a guide to my self-hosted Kubernetes environment and technical experiments"
weight = 1
sort_by = "weight"

[extra]
+++

My homelab is a bare metal k3s cluster running on a mix of dedicated and spare hardware. This documentation covers the architecture, configuration, and operational practices I use to maintain this environment.

## What is This?

This homelab serves as:
- A platform for running personal projects and services
- A testing ground for new technologies and DevOps practices
- A learning environment for Kubernetes, networking, and infrastructure automation
- A reliable self-hosted alternative to cloud services

## Hardware

The cluster runs on 4 heterogeneous nodes:

### AOOSTAR Gem 12 (Primary Node)
- **RAM**: 64GB
- **CPU**: [AMD Ryzen 7 8845HS](https://www.amd.com/en/products/processors/laptop/ryzen/8000-series/amd-ryzen-7-8845hs.html)
- **Storage**: 
  - 1 TB Samsung EVO SSD
  - 2 TB WD Black SSD

### Orange Pi Zero 3 (ARM Node)
- **RAM**: 2GB
- **CPU**: Allwinner H618 (ARM64)
- **Role**: Lightweight workloads, testing ARM compatibility

### ASUS Zenbook 20215 (Laptop Node)
- **RAM**: 8GB
- **CPU**: Intel i7
- **Role**: General compute, development workloads

### HP EliteDesk G2 (Mini PC)
- **RAM**: 16GB
- **CPU**: Intel i5
- **Role**: General compute, services

## Software Stack

### Operating System
All nodes run [NixOS](https://nixos.org/), providing:
- Immutable infrastructure with reproducible builds
- Declarative configuration management
- Atomic upgrades and rollbacks
- Consistent environment across heterogeneous hardware

The NixOS configurations are maintained in a separate [dotfiles repository](https://github.com/cunialino/dotfiles).

### Kubernetes Distribution
[k3s](https://k3s.io/) - Lightweight Kubernetes distribution ideal for resource-constrained environments and edge deployments.

### Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **CNI** | [Cilium](networking/cni) | eBPF-based networking and security |
| **Storage** | [Longhorn](storage/longhorn) | Distributed block storage |
| **GitOps** | [ArgoCD](cicd) | Declarative continuous delivery |
| **Monitoring** | [Prometheus/Grafana](monitoring) | Metrics and visualization |
| **Secrets** | [External Secrets Operator](utils/eso) | Secret management with Bitwarden |

## Documentation Approach

> **Disclaimer**: Most of this documentation is generated with AI assistance (Gemini CLI) and reviewed for accuracy.
> 
> I focus primarily on coding and infrastructure automation, so documentation is maintained pragmatically to support those activities.

## What's Next?

- **[Cluster Architecture](/introduction/cluster-architecture)** - Visual overview of how components interact
- **[Security Model](/introduction/security)** - Security practices and network policies
- **[Getting Started](/getting-started)** - Navigate the documentation

## Quick Stats

- **Nodes**: 4 (mixed architecture: x86_64 + ARM64)
- **Total RAM**: ~90GB
- **Total Storage**: Mixed SSDs across nodes
- **Uptime Target**: 24/7 (within homelab constraints)
- **Deployment Method**: GitOps via ArgoCD
