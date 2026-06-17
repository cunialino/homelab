+++
template = "landing.html"

[extra]
section_order = ["hero", "features"]

[extra.hero]
title = "Welcome to my homelab!"
description = "A bare metal k3s cluster, where I can run projects, test new tech and break stuff so that I can learn how to fix them"
badge = "K8s • GitOps • Self Hosting"
image = "images/landing.png"
cta_buttons = [
    { text = "Get Started", url = "/introduction", style = "primary" },
    { text = "View on GitHub", url = "https://github.com/cunialino/homelab", style = "secondary" },
]
[extra.features_section]
title = "Main Features"
description = "A production-grade Kubernetes environment engineered for high-performance networking and automated workflows."
[[extra.features_section.features]]
title = "CI/CD Pipeline"
desc = "GitOps workflows with ArgoCD and Kubernetes-native GitHub Actions runners"
icon = "fa-solid fa-code-merge"
[[extra.features_section.features]]
title = "Prometheus & Grafana"
desc = "Full-stack observability with custom alerting and Loki log aggregation"
icon = "fa-solid fa-chart-bar"
[[extra.features_section.features]]
title = "Longhorn"
desc = "Distributed block storage with replication and snapshots"
icon = "fa-solid fa-hard-drive"
[[extra.features_section.features]]
title = "CloudNativePG"
desc = "Managed PostgreSQL clusters with automated replication and failover"
icon = "fa-solid fa-database"
[[extra.features_section.features]]
title = "Garage"
desc = "S3-compatible object storage for data lake architectures"
icon = "fa-solid fa-cloud"
[[extra.features_section.features]]
title = "NATS"
desc = "High-performance messaging and event streaming"
icon = "fa-solid fa-envelope"
[[extra.features_section.features]]
title = "External Secrets"
desc = "Bitwarden-backed secret injection with zero git exposure"
icon = "fa-solid fa-lock"
+++
