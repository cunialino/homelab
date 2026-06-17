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

Vikunja is deployed via [ArgoCD](/cicd/argocd/), with its Application definition
at [apps/vikunja.yaml](https://github.com/cunialino/homelab/tree/main/apps/vikunja.yaml)
and configuration at [base/vikunja/](https://github.com/cunialino/homelab/tree/main/base/vikunja/).

The deployment uses the `longhorn-wdblack` storage class for persistent volume
storage. The Vikunja secret (DB password, JWT secret) is provisioned via an
ExternalSecret from Bitwarden Secrets Manager.
