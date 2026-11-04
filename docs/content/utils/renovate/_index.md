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

Renovate is deployed with [Flux](/cicd/flux/) in the `renovate` namespace. It uses the official Renovate Helm chart and runs every 6 hours as a CronJob.

The `HelmRelease`, its `HelmRepository` and its token live in [apps/renovate/base/](https://github.com/cunialino/homelab/tree/main/apps/renovate/base/).

## Configuration

All Renovate configuration lives inside the Helm values — there is no `renovate.json` in the repository.

### Repositories

Renovate scans these repositories for dependency updates:

- `cunialino/homelab`
- `cunialino/crypto-lakehouse`
- `cunialino/myai`

### Enabled Managers

Renovate bumps `HelmRelease` chart versions and links each one to its `HelmRepository` through the `flux` manager, and also covers Helm values, plain Kubernetes manifests, Dockerfiles and Docker Compose files.

Two details matter once manifests, rather than an app-of-apps, are the source of truth. The `flux` manager needs `managerFilePatterns` spelled out, because its default matches only `gotk-components.yaml` and would otherwise leave every chart pin invisible. And a `HelmRelease` is only linked to its source when the manifest states the namespace, either in `metadata.namespace` or in `spec.chart.spec.sourceRef.namespace`. The config is embedded as a YAML block scalar, so it is strict JSON: a `#` comment inside it breaks the run, which is why the explanations sit in the YAML around it.

### Authentication

A GitHub personal access token is provided as `RENOVATE_TOKEN` from a [SOPS-encrypted Secret](/utils/secrets/) in [secret-token.yaml](https://github.com/cunialino/homelab/blob/main/apps/renovate/base/secret-token.yaml).

## Pull Request Workflow

Renovate uses the Dependency Dashboard with manual approval required — no auto-merging. PRs are limited per hour and tagged with the `renovate` label. This gives me control over when and what gets updated.
