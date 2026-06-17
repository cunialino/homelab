+++
title = "Renovate"
weight = 3
sort_by = "weight"

[extra]
+++

[Renovate](https://docs.renovatebot.com/) is a bot that automatically creates pull requests to update dependencies.

## Why Renovate

I chose to run Renovate as a Kubernetes CronJob rather than as a GitHub App to keep everything inside my cluster.

## Deployment

Renovate is deployed via [ArgoCD](/apps/_index.md) in the `renovate` namespace. It uses the official Renovate Helm chart and runs every 6 hours as a CronJob.

You can find the ArgoCD Application at [apps/renovate.yaml](https://github.com/cunialino/homelab/tree/main/apps/renovate.yaml) and the configuration at [base/renovate/values.yaml](https://github.com/cunialino/homelab/tree/main/base/renovate/values.yaml).

## Configuration

All Renovate configuration lives inside the Helm values — there is no `renovate.json` in the repository.

### Repositories

Renovate scans these repositories for dependency updates:

- `cunialino/homelab`
- `cunialino/crypto-lakehouse`

### Enabled Managers

Renovate handles updates across ArgoCD Application files, Helm values, Kubernetes manifests, Dockerfiles, and Docker Compose files. It uses a custom regex manager to track its own chart version.

### Authentication

A GitHub personal access token is provisioned as `RENOVATE_TOKEN` via an ExternalSecret from Bitwarden Secrets Manager.

## Pull Request Workflow

Renovate uses the Dependency Dashboard with manual approval required — no auto-merging. PRs are limited per hour and tagged with the `renovate` label. This gives me control over when and what gets updated.
