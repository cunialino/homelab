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

OxiCloud is deployed with [Flux](/cicd/flux/). Upstream ships its Helm chart inside the
project repository (`charts/oxicloud`) and does not publish it to a Helm registry, so
[apps/oxicloud/base/](https://github.com/cunialino/homelab/tree/main/apps/oxicloud/base/)
is a `GitRepository` pinned to the `v0.9.3` tag, a `HelmChart` pointing at
`./charts/oxicloud` inside it, and a `HelmRelease` with its values written inline. That
detour is what source-controller expects when a chart lives in a git tree rather than a
chart repository.

File storage uses the `longhorn-wdblack` storage class (20 GiB, `ReadWriteOnce`).
The Ingress is the tailscale class, and `OXICLOUD_COOKIE_SECURE` is set because the
tailscale proxy terminates TLS.

## Database

OxiCloud requires an external PostgreSQL, so it uses the shared CloudNativePG
`pg-cluster`: the database is
[infrastructure/configs/postgres/oxicloud.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/oxicloud.yaml)
and the credentials are [SOPS-encrypted Secrets](/utils/secrets/) — the role credential
the operator reads is
[role-secret-oxicloud.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/role-secret-oxicloud.yaml),
the copy the StatefulSet reads is
[apps/oxicloud/base/secret-db.yaml](https://github.com/cunialino/homelab/blob/main/apps/oxicloud/base/secret-db.yaml).

Two files, because `secretKeyRef` only resolves inside the pod's own namespace and the
CNPG operator cannot write outside `cnpg-system`. The application-side Secret carries a
`uri` key as well: the connection-string DSN, with the password embedded. That is why the
password avoids characters that would need percent-encoding in a URI.

## Not enabled yet

Collabora/WOPI (`wopi.enabled: false`) and OIDC are left for follow-ups, and the
Application is manual-sync like the other self-hosted apps so the first rollout stays
deliberate.
