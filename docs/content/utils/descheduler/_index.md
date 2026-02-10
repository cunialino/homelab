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

The Descheduler application is deployed via ArgoCD, and its configuration can be found in [apps/descheduler.yaml](https://github.com/cunialino/homelab/tree/main/apps/descheduler.yaml).
