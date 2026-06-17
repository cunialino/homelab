+++
title = "ArgoCD"
weight = 1
sort_by = "weight"

[extra]
+++

[ArgoCD](https://argo-cd.readthedocs.io/) is the first step to create a reproducible environment and it helps me manage deployments on Kubernetes effectively.

I chose the "app of apps" pattern to manage my applications. This means I only needed to bootstrap a single root application, and all other applications are then automatically synchronized by ArgoCD. You can find the root application definition at [bootstrap/root-app.yaml](https://github.com/cunialino/homelab/tree/main/bootstrap/root-app.yaml). Individual application definitions are located in the [apps/](https://github.com/cunialino/homelab/tree/main/apps/) directory.
