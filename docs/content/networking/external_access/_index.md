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

The [Tailscale Operator](https://tailscale.com/docs/features/kubernetes-operator) is deployed with [Flux](/cicd/flux/) in the `tailscale` namespace:

- **Chart**: `tailscale-operator` from `pkgs.tailscale.com/helmcharts`, pinned to an exact version
- **Values**: written inline in the `HelmRelease`
- **OAuth Secret**: `operator-oauth`, a [SOPS-encrypted Secret](/utils/secrets/)

### Key Technical Details

The `HelmRelease` in
[infrastructure/controllers/tailscale-operator/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/tailscale-operator/)
installs the chart from `pkgs.tailscale.com/helmcharts`. The OAuth credentials
(`client_id`, `client_secret`) are committed encrypted with SOPS in
[secret-oauth.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/controllers/tailscale-operator/secret-oauth.yaml)
and decrypted by Flux at apply time.

Ingresses reach the operator through the `ProxyClass` objects in
[infrastructure/configs/proxy-classes/](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/proxy-classes/) —
that is what a `tailscale.com/proxy-class` annotation on an Ingress names.

## What it's used for

### 1. Secure remote cluster access

My k3s cluster services are reachable via Tailscale tailnet without exposing ports:

- **API Server**: Access via Tailscale IP (no public port 6443 needed)
- **Services**: Internal services exposed only within the private tailnet
- **Management**: `kubectl` and other tools connect securely through Tailscale

### 2. Credential security

The OAuth client credentials are stored encrypted in Git with [SOPS and age](/utils/secrets/) rather than pulled from an external store at runtime. The ciphertext is what a review sees; the cluster is handed a normal `Secret`.

- **Encrypted in Git**: only the `data` block of the manifest is ciphertext, so the diff still reads
- **One key**: the age private key sits in `flux-system/sops-age` and never enters Git
- **No runtime dependency**: the operator starts without reaching a secrets API

## References

- [Tailscale Operator Documentation](https://tailscale.com/docs/features/kubernetes-operator)
- [Tailscale Official Docs](https://tailscale.com/docs/)
- [Tailscale operator manifests](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/tailscale-operator/)
- [SOPS-encrypted OAuth Secret](https://github.com/cunialino/homelab/blob/main/infrastructure/controllers/tailscale-operator/secret-oauth.yaml)
- [ProxyClasses](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/proxy-classes/)
