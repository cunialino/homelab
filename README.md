# Homelab Infrastructure

A Kubernetes cluster running on 4 NixOS nodes using k3s.

## Table of Contents
- [Overview](#overview)
- [Infrastructure](#infrastructure)
- [Bootstrapping](#bootstrapping)
- [Configuration Files](#configuration-files)
- [Contributing](#contributing)

## Overview

A minimal k3s cluster with Cilium CNI configured on NixOS. The setup includes:
- 4-node cluster
- Custom nixos configuration module
- Cilium CNI with specific values

## Infrastructure

### Nodes
- 4 NixOS nodes
- k3s cluster
- Cilium CNI

### Configuration Files
- [Module](https://github.com/cunialino/dotfiles/blob/main/sys_mods/k3s/default.nix)
- [Cilium Values](./cilium.yaml)

## Bootstrapping Process

1. Run `nixos-rebuild` on all nodes
2. Apply Cilium config: `cilium install --kubeconfig <path>`
3. Deploy ArgoCD: `kubectl apply -f https://argo-cd.readthedocs.io/en/stable/manifests/install.yaml`
4. Configure ArgoCD via web UI
5. Apply bootstrap config: `kubectl apply -f ./bootstrap/root-app.yaml`
