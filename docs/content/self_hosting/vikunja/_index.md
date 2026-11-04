+++
title = "Vikunja"
weight = 1
sort_by = "weight"

[extra]
+++

I use [Vikunja](https://vikunja.io/) as my personal self-hosted to-do app.

This was my first experiment with self-hosting — I chose this app because it's
not critical, and even if my homelab shuts down unexpectedly it doesn't bother
me much.

## Configuration

Vikunja is deployed with [Flux](/cicd/flux/): its Deployment, ConfigMap, PVC, Service and
Ingress are plain manifests in [apps/vikunja/base/](https://github.com/cunialino/homelab/tree/main/apps/vikunja/base/),
synced by [clusters/homelab/apps/vikunja.yaml](https://github.com/cunialino/homelab/blob/main/clusters/homelab/apps/vikunja.yaml).

The deployment uses the `longhorn-wdblack` storage class for persistent volume
storage. The Vikunja secret (DB password, JWT secret) is a
[SOPS-encrypted Secret](/utils/secrets/), and so is the CNPG role credential beside it:
`secret-app.yaml` for Vikunja itself, `secret-cnpg-role.yaml` for the managed role.
That pairing in one directory is deliberate — this layer owns objects in both
`vikunja` and `cnpg-system`.
