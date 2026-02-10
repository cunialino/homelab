+++
template = "landing.html"

[extra]
version = "v0.1.0"
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
desc = "Managing cluster via argocd and github actions"
icon = "fa-solid fa-code-merge"
[[extra.features_section.features]]
title = "Cilium"
desc = "High performance and security focused CNI"
icon = "fa-solid fa-network-wired"
[[extra.features_section.features]]
title = "Prometheus & Grafana"
desc = "Full-stack monitoring and metrics visualization."
icon = "fa-solid fa-chart-bar"
[[extra.features_section.features]]
title = "Longhorn"
desc = "Highly available distributed block storage."
icon = "fa-solid fa-hard-drive"
+++
