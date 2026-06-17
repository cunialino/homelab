+++
title = "CICD Pipeline"
weight = 2
sort_by = "weight"

[extra]
+++

Every good setup starts with automating the boring parts. Hence, one of the first things I set up is the CI/CD pipeline.

## ArgoCD

[ArgoCD](/cicd/argocd/) manages all deployments on my cluster using the "app of apps" pattern. It ensures my environment is reproducible and synchronized with Git.

## ARC Runners

I run [ARC Runners](/cicd/arc/) to execute GitHub Actions workflows on my own infrastructure. They handle everything from building container images with nix to deploying this documentation site.
