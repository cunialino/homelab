+++
title = "CICD Pipeline"
weight = 2
sort_by = "weight"

[extra]
+++

Every good setup starts with automating the boring parts. Hence, one of the first
things I set up is the CI/CD pipeline.

## ArgoCD

ArgoCD is the first step to create a reproducible environment and it helps
me manage deployments on Kubernetes effectively.

I chose the "app of apps" pattern to manage my applications. This means I only needed to bootstrap a single root application, and all other applications are then automatically synchronized by ArgoCD. You can find the root application definition at [bootstrap/root-app.yaml](https://github.com/cunialino/homelab/tree/main/bootstrap/root-app.yaml). Individual application definitions are located in the [apps/](https://github.com/cunialino/homelab/tree/main/apps/) directory.

## ARC Runners

I also deployed the [Action Runners Controller](https://github.com/actions/actions-runner-controller) to 
be able to run GitHub Actions on my cluster.
This for example is how I deploy the GitHub Pages you are reading right now, altough arc runners were not
crucial for deploying github pages, they will be particularly useful for building docker images and storing them on 
my local machines and to serve dbt docs.

My ARC Runners are configured via [apps/arc.yaml](https://github.com/cunialino/homelab/tree/main/apps/arc.yaml). I use `longhorn` as the storage class for the runner's work volume, ensuring persistent storage for build processes. The GitHub personal access token required for authentication is securely managed through External Secrets, referenced in [base/arc/secret_pat.yaml](https://github.com/cunialino/homelab/tree/main/base/arc/secret_pat.yaml). 
