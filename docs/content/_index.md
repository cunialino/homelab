+++
template = "landing.html"

[extra]
version = "v0.1.0"
section_order = ["hero", "features", "architecture"]

[extra.hero]
title = "Welcome to my homelab!"
description = "A bare metal k3s cluster for running projects, testing new technologies, and experimenting safely with self-hosted solutions"
badge = "K8s • GitOps • Self Hosting"
image = "images/landing.png"
cta_buttons = [
    { text = "Get Started", url = "/getting-started", style = "primary" },
    { text = "Introduction", url = "/introduction", style = "secondary" },
    { text = "View on GitHub", url = "https://github.com/cunialino/homelab", style = "secondary" },
]

[extra.features_section]
title = "Main Features"
description = "A production-grade Kubernetes environment engineered for high-performance networking and automated workflows."

[[extra.features_section.features]]
title = "Advanced CI/CD Pipeline"
desc = "Fully automated deployments using ArgoCD with GitHub Actions. Implements GitOps workflows for consistent and reliable infrastructure management."
icon = "fa-solid fa-terminal"

[[extra.features_section.features]]
title = "Cilium Security Framework"
desc = "Enterprise-grade network security with eBPF-based policy enforcement. Implements zero-trust networking with automatic network policy generation."
icon = "fa-solid fa-shield-halved"

[[extra.features_section.features]]
title = "Custom Monitoring Stack"
desc = "Tailored metrics collection with Prometheus + Grafana for real-time observability. Includes dashboards for cluster health and resource utilization."
icon = "fa-solid fa-chart-line"

[[extra.features_section.features]]
title = "High Availability Storage"
desc = "Distributed block storage with Longhorn for mission-critical workloads. Implements automated backup/restore and multi-node replication."
icon = "fa-solid fa-database"

[extra.architecture]
title = "Cluster Architecture"
description = "Overview of the self-hosted Kubernetes environment with key components:"
image = "https://picsum.photos/800/400?random=1"
caption = "Kubernetes control plane • CNI (Cilium) • Storage (Longhorn) • Monitoring (Prometheus/Grafana) • CI/CD (ArgoCD/GitHub Actions)"

[[extra.architecture.components]]
title = "Kubernetes Control Plane"
desc = "Custom-configured k3s cluster with etcd for persistent storage and automated node management"
icon = "fa-solid fa-server"

[[extra.architecture.components]]
title = "Network Security"
desc = "Cilium provides eBPF-based network policies and automatic security rule enforcement"
icon = "fa-solid fa-shield-halved"

[[extra.architecture.components]]
title = "Distributed Storage"
desc = "Longhorn handles block storage with multi-node replication and automated backup/restore"
icon = "fa-solid fa-hdd"

[[extra.architecture.components]]
title = "Observability Stack"
desc = "Prometheus + Grafana for real-time metrics and custom dashboards"
icon = "fa-solid fa-chart-line"

[[extra.architecture.components]]
title = "Continuous Delivery"
desc = "ArgoCD with GitHub Actions enables zero-downtime deployments and GitOps workflows"
icon = "fa-solid fa-code-merge"
+++