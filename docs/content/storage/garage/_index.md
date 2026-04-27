+++
title = "Garage"
weight = 2
sort_by = "weight"
+++

[Garage](https://garagehq.deuxfleurs.fr/) is a lightweight s3 object storage I deployed in my homelab.

I chose garage for its reliability after minio was archived.

I also considered rustfs, but it is not as mature and was giving me OOM errors
when running queries on it.

## Configuration

I deploy RustFS via ArgoCD, with its configuration defined in 
[base/rustfs/](https://github.com/cunialino/homelab/tree/main/base/garage/).
