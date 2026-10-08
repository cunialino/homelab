+++
title = "OxiCloud"
weight = 3
sort_by = "weight"

[extra]
+++

[OxiCloud](https://github.com/AtalayaLabs/OxiCloud) is a self-hosted cloud storage
server — files, photos, calendar and contacts in one binary. It is written in Rust,
speaks the Nextcloud sync API (so the desktop and mobile clients work against it),
and keeps its blobs in a content-addressed store on disk while all metadata lives in
PostgreSQL.

It serves on the tailnet at [https://oxicloud.tail2f38ea.ts.net](https://oxicloud.tail2f38ea.ts.net)
— TLS is issued by the tailnet itself through the tailscale Ingress, so there is no
certificate to manage.

## Configuration

OxiCloud is deployed via [ArgoCD](/cicd/argocd/). Upstream ships its Helm chart
inside the project repository (`charts/oxicloud`) and does not publish it to a Helm
registry, so the Application at
[apps/oxicloud.yaml](https://github.com/cunialino/homelab/tree/main/apps/oxicloud.yaml)
uses two sources: the chart is pulled from the upstream git repo by `path` (pinned to
the `v0.9.2` tag), and its values come from this repo at
[base/oxicloud/values.yaml](https://github.com/cunialino/homelab/tree/main/base/oxicloud/values.yaml)
through a `$my-repo` reference — the same layout as the other apps.

File storage uses the `longhorn-wdblack` storage class (20 GiB, `ReadWriteOnce`).
The Ingress is the tailscale class, and `OXICLOUD_COOKIE_SECURE` is set because the
tailscale proxy terminates TLS.

## Database

OxiCloud requires an external PostgreSQL, so it uses the shared CloudNativePG
`pg-cluster` the same way Nextcloud does: the database is
[base/cnpg/oxicloud.yaml](https://github.com/cunialino/homelab/tree/main/base/cnpg/oxicloud.yaml)
and the credentials come from Bitwarden through
[base/cnpg/secret_oxicloud.yaml](https://github.com/cunialino/homelab/tree/main/base/cnpg/secret_oxicloud.yaml)
— no password in git. That file holds a pair of ExternalSecrets reading the same item:
one in `cnpg-system` for the CNPG managed role, and one in the `oxicloud` namespace
whose `uri` key the StatefulSet reads as its connection-string DSN. The second one is
needed because `secretKeyRef` only resolves inside the pod's own namespace, and it
cannot live under `base/oxicloud/` because that path is a `ref` source, whose plain
manifests ArgoCD never applies.

## Not enabled yet

Collabora/WOPI (`wopi.enabled: false`) and OIDC are left for follow-ups, and the
Application is manual-sync like the other self-hosted apps so the first rollout stays
deliberate.
