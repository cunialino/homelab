+++
title = "Descheduler"
weight = 1
sort_by = "weight"

[extra]
+++

I deployed the [descheduler operator](https://github.com/kubernetes-sigs/descheduler)
to rebalance the pods after machine reboots.

The cluster is running on my home hardware, and I update it frequently as one of
the nodes is also my daily driver.

After reboots, I always ended up with one of the nodes hosting most of the
workloads, hence I wanted something to automatically rebalance them across
the cluster.

The Descheduler is deployed with [Flux](/cicd/flux/), and its `HelmRelease` and values live in [infrastructure/controllers/descheduler/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/descheduler/).
