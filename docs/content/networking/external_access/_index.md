+++
title = "External Access"
weight = 3
sort_by = "weight"
+++

I put everything inside my [tailnet](https://tailscale.com/), which made everything
really easy even though I'm not a VPN expert.

I used the [Tailscale Operator](https://tailscale.com/docs/features/kubernetes-operator) to
make my cluster services reachable from the outside. The `tailscale-operator` is deployed via ArgoCD, with its application definition in [apps/tailscale.yaml](https://github.com/cunialino/homelab/tree/main/apps/tailscale.yaml).

For secure management of Tailscale OAuth credentials, I leverage External Secrets. The `tailscale-operator` references an External Secret defined in [base/tailscale/secrets.yaml](https://github.com/cunialino/homelab/tree/main/base/tailscale/secrets.yaml), which fetches the `client_id` and `client_secret` from my Bitwarden Secrets Manager. This ensures that sensitive credentials are not directly stored in my Git repository.
