+++
title = "Introduction"
description = "Hardware, topology, and design decisions"
weight = 1
sort_by = "weight"

[extra]
+++

My homelab is a bare metal k3s cluster spread across four machines — a mix of
a mini-PC, a single-board computer, a laptop, and an old desktop. It runs 24/7
and serves as both a self-hosting platform and a testbed for new technology.

## Goals

- **Run reliable self-hosted services** — Vikunja, Nextcloud, and supporting
  infrastructure that I use daily
- **Experiment with data infrastructure** — Streaming pipelines, messaging
  (NATS), object storage (Garage), and managed Postgres (CloudNativePG)
- **Build a reproducible, GitOps-driven cluster** — Everything declarative,
  synchronized via ArgoCD, secrets injected at runtime from Bitwarden
- **Learn by breaking things** — Test new tech, recover from failures, and
  understand how production-grade K8s patterns work at homelab scale

## Hardware

| Machine | Model | CPU | RAM | Storage | Role |
|---------|-------|-----|-----|---------|------|
| elcungem | AOOSTAR GEM 12 | Ryzen 7 8845HS | 64 GB | 1 TB SSD + 2 TB WD Black | Control plane + Longhorn |
| elcunhp1 | HP Elite Desk G2 | Intel i5 | 16 GB | 2 TB SSD | Control plane + Longhorn |
| elcunal | ASUS Zenbook 20215 | Intel i7 | 8 GB | — | Control plane |
| opizero3 | Orange Pi Zero 3 | Allwinner H618 | 2 GB | — | Worker (tainted) |

## Software Stack

| Component | Version / Notes |
|-----------|-----------------|
| OS | [NixOS](https://nixos.org/) (unstable channel) |
| Kubernetes | [k3s](https://k3s.io/) with embedded etcd, HA control plane |
| CNI | [Cilium](https://cilium.io/) with eBPF, kube-proxy replacement |
| HA VIP | [kube-vip](https://kube-vip.io/) — `192.168.0.100:6443` |
| GitOps | [ArgoCD](https://argo-cd.readthedocs.io/) — app-of-apps pattern |
| Secrets | [External Secrets Operator](https://external-secrets.io/) + Bitwarden |
| Block Storage | [Longhorn](https://longhorn.io/) — 2 replicas, XFS, trim |
| Object Storage | [Garage](https://garagehq.deuxfleurs.fr/) — single-node S3 |
| Database | [CloudNativePG](https://cloudnative-pg.io/) — 3-instance Postgres |
| Messaging | [NATS](https://nats.io/) — 3-node cluster + JetStream |
| Monitoring | Prometheus + Grafana + Loki + Alloy + Alertmanager |
| External Access | [Tailscale](https://tailscale.com/) operator — no public ports |
| Automation | [Renovate](https://docs.renovatebot.com/) — dependency PRs |
| Scheduling | [Descheduler](https://github.com/kubernetes-sigs/descheduler) — post-reboot rebalance |

## Key Design Decisions

- **k3s over full K8s** — Lightweight control plane, embedded etcd, single
  binary. Sufficient for homelab scale with much less resource overhead.
- **Cilium over Flannel/Calico** — eBPF-native networking replaces kube-proxy,
  provides Hubble observability, and enables fine-grained network policies
  without performance penalties.
- **NixOS** — Reproducible node configuration via a single module. All nodes
  share the same k3s module from my [dotfiles](https://github.com/cunialino/dotfiles).
- **GitOps with ArgoCD** — Self-healing, drift detection, and a single
  `bootstrap/root-app.yaml` to bring up the entire cluster.
- **No public exposure** — Everything reaches me through Tailscale. No port
  forwarding, no cloud firewall rules, no attack surface.

## Cluster Topology

{% mermaid() %}
flowchart TB
    subgraph k3s_cluster["K3S Cluster"]
        direction TB
        
        switch[NETWORK SWITCH<br/>Ethernet]
        
        elcungem["elcungem<br/>AOOSTAR GEM 12<br/>Ryzen 7 8845HS<br/>64GB RAM<br/>2TB SSDs + Longhorn"]
        orange_pi["orange_pi<br/>Orange Pi Zero 3<br/>H618<br/>2GB RAM"]
        zenbook["zenbook<br/>ASUS Zenbook 2025<br/>i7<br/>8GB RAM"]
        elcunhp1["elcunhp1<br/>HP Elite Desk G2<br/>i5<br/>16GB RAM<br/>2TB SSDs + Longhorn"]
        
        switch --> elcungem
        switch --> orange_pi
        switch --> zenbook
        switch --> elcunhp1
    end
    
    style switch fill:#888,stroke:#333
    style elcungem fill:#bbf,stroke:#333
    style elcunhp1 fill:#bbf,stroke:#333
    style orange_pi fill:#ccc,stroke:#333
    style zenbook fill:#ccc,stroke:#333
{% end %}

## Architecture Overview

{% mermaid() %}
flowchart LR
    subgraph access["Access Layer"]
        tailscale["Tailscale VPN<br/>tail2f38ea.ts.net"]
    end
    subgraph gitops["GitOps"]
        argocd["ArgoCD<br/>app-of-apps"]
    end
    subgraph network["Networking"]
        cilium["Cilium CNI<br/>eBPF + Hubble"]
        kubevip["kube-vip<br/>192.168.0.100"]
    end
    subgraph storage["Storage"]
        longhorn["Longhorn<br/>Block Storage<br/>2 replicas"]
        garage["Garage<br/>S3 Object Store"]
    end
    subgraph data["Data Layer"]
        cnpg["CloudNativePG<br/>PostgreSQL Cluster"]
        nats["NATS<br/>JetStream Messaging"]
    end
    subgraph apps["Applications"]
        nextcloud["Nextcloud"]
        vikunja["Vikunja"]
    end
    subgraph observability["Observability"]
        alloy["Alloy"]
        loki["Loki"]
        prom["Prometheus"]
        grafana["Grafana"]
        alertmgr["Alertmanager"]
    end
    subgraph security["Security"]
        eso["ESO + Bitwarden"]
        cert["cert-manager"]
    end

    tailscale --> argocd
    tailscale --> grafana
    tailscale --> longhorn
    tailscale --> nextcloud
    argocd --> cilium
    argocd --> kubevip
    argocd --> longhorn
    argocd --> garage
    argocd --> cnpg
    argocd --> nats
    argocd --> nextcloud
    argocd --> vikunja
    argocd --> alloy
    argocd --> loki
    argocd --> prom
    argocd --> grafana
    argocd --> alertmgr
    argocd --> eso
    argocd --> cert
    cnpg --> nextcloud
    cnpg --> vikunja
    longhorn --> cnpg
    longhorn --> nats
    longhorn --> nextcloud
    longhorn --> vikunja
    longhorn --> garage
    longhorn --> prom
    longhorn --> loki
    longhorn --> grafana
    garage --> nextcloud
    alloy --> loki
    alloy --> prom
    prom --> grafana
    prom --> alertmgr
    nats --> nextcloud
    eso --> cert
{% end %}

#### A Note on Documentation

Most content here was drafted with AI assistance and reviewed for accuracy.
I focus my energy on coding and infrastructure — this site is a snapshot of a
live, evolving system rather than a polished product. Pull requests and
corrections are welcome.
