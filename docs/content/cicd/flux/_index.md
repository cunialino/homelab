+++
title = "Flux"
weight = 1
sort_by = "weight"

[extra]
+++

[Flux](https://fluxcd.io/) keeps everything on this cluster in sync with Git. I use it in the same shape as the "app of apps" pattern: the cluster bootstraps from one directory, and every application is a small sync object that points at its own folder of manifests.

## Layout

[clusters/homelab/](https://github.com/cunialino/homelab/tree/main/clusters/homelab/) is the entry point. `flux-system/` holds Flux's own components and the sync object for this repository. `apps/` and `infra/` then hold one `Kustomization` per application, each pointing at a path:

* [apps/](https://github.com/cunialino/homelab/tree/main/apps/) — per-application manifests: the `HelmRelease` and its values, plain manifests, and any [Secrets](/utils/secrets/) the application owns.
* [infrastructure/controllers/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/) — operators and cluster-wide controllers: CloudNativePG, Longhorn, KEDA, NATS, the Tailscale operator, Actions Runner Controller, the descheduler.
* [infrastructure/configs/](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/) — the custom resources those operators act on: the CNPG `Cluster` with its `Database` objects and role credentials, the Longhorn settings, the Tailscale `ProxyClass`es.
* [infrastructure/sources/](https://github.com/cunialino/homelab/tree/main/infrastructure/sources/) — the other repositories that ship workloads.

Where an application needs something to exist first — a database, an operator, a Source — its sync object says so with `dependsOn`. That makes startup order explicit instead of leaving it to luck, which matters most for apps that connect to Postgres during boot.

## More than one repository

This repository is the only bootstrap, but not the only source. [crypto-lakehouse.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/sources/crypto-lakehouse.yaml) and [myai.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/sources/myai.yaml) pull in those repositories, and a pointer such as [clusters/homelab/apps/lakekeeper.yaml](https://github.com/cunialino/homelab/blob/main/clusters/homelab/apps/lakekeeper.yaml) reads a path inside one of them rather than here.

Cluster-wide pieces stay in this repository — the CNPG `Cluster` and role credentials, the StorageClass, the `ProxyClass`es — so a workload repository only ever describes its own workload. Both sources ignore everything except their `clusters/` directory, so application code there can move around without touching the cluster.

## Applying changes

A `HelmRelease` is a normal Helm release, so `helm list -A` shows what is deployed and `helm history` shows the revisions. Flux reconciles on an interval and self-heals, which means editing a live object gets reverted; the change has to go through Git.
