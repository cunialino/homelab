+++
title = "CICD Pipeline"
weight = 2
sort_by = "weight"

[extra]
+++

Every good setup starts with automating the boring parts. Hence, one of the first things I set up is the CI/CD pipeline.

## Flux

[Flux](/cicd/flux/) keeps every deployment on my cluster synchronized with Git, one sync object per application. It ensures my environment is reproducible without a UI: a change that is not in Git gets reverted.

## ARC Runners

I run [ARC Runners](/cicd/arc/) to execute GitHub Actions workflows on my own infrastructure. They handle everything from building container images with nix to deploying this documentation site.
