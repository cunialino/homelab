+++
title = "External Access"
description = "Secure external access via Tailscale and Kubernetes Operator"
weight = 3
sort_by = "weight"

[extra]
+++

[External Access](https://tailscale.com/) allows me to securely reach my cluster services from outside my home network without exposing them to the public internet.

## Why I installed it

I chose [Tailscale](https://tailscale.com/) as my external access solution because:

- **Security**: Creates a private network over the public internet, eliminating the need to expose services publicly
- **Simplicity**: No complex firewall rules or port forwarding required
- **Zero configuration**: No expert knowledge needed to set up
- **Operator support**: Tailscale Operator simplifies Kubernetes integration

## How I installed it

The [Tailscale Operator](https://tailscale.com/docs/features/kubernetes-operator) is deployed via [ArgoCD](/cicd/argocd/) in the `tailscale` namespace:

- **Chart**: `tailscale-operator` from pkgs.tailscale.com
- **Values**: OAuth credentials managed via an External Secret
- **OAuth Secret**: `operator-oauth` fetched from Bitwarden Secrets Manager

### Key Technical Details

The [ArgoCD Application](https://github.com/cunialino/homelab/tree/main/apps/tailscale.yaml)
installs the `tailscale-operator` chart from `pkgs.tailscale.com/helmcharts`.
OAuth credentials (`client_id`, `client_secret`) are fetched from Bitwarden
Secrets Manager via an
[ExternalSecret](https://github.com/cunialino/homelab/tree/main/base/tailscale/secrets.yaml).

## What it's used for

### 1. Secure remote cluster access

My k3s cluster services are reachable via Tailscale tailnet without exposing ports:

- **API Server**: Access via Tailscale IP (no public port 6443 needed)
- **Services**: Internal services exposed only within the private tailnet
- **Management**: `kubectl` and other tools connect securely through Tailscale

### 2. Credential security

External Secrets integration ensures sensitive credentials never touch the Git repository:

- **Bitwarden**: Stores OAuth client credentials securely
- **ClusterSecretStore**: Fetches secrets at runtime
- **No git exposure**: Credentials remain encrypted and out of version control

## References

- [Tailscale Operator Documentation](https://tailscale.com/docs/features/kubernetes-operator)
- [Tailscale Official Docs](https://tailscale.com/docs/)
- [ArgoCD Application](https://github.com/cunialino/homelab/tree/main/apps/tailscale.yaml)
- [External Secret Configuration](https://github.com/cunialino/homelab/tree/main/base/tailscale/secrets.yaml)
- [External Secrets Operator](https://external-secrets.io/)
- [Bitwarden Secrets Manager Integration](https://external-secrets.io/v1beta1/secretstores/bitwarden/)
