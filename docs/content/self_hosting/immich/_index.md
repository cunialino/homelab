+++
title = "Immich"
weight = 4

[extra]
+++

[Immich](https://immich.app/) is my photo library and backup target — the mobile app uploads
everything, the server generates thumbnails and preview videos, and machine learning does the
face detection and semantic search.

It serves on the tailnet at [https://immich.tail2f38ea.ts.net](https://immich.tail2f38ea.ts.net).
The mobile apps reach it there, which is also why the Ingress is the tailscale class rather than
something I would have to expose through the firewall.

## Configuration

Deployed with [Flux](/cicd/flux/): three workloads and their plumbing as plain manifests in
[apps/immich/base/](https://github.com/cunialino/homelab/tree/main/apps/immich/base/), synced by
[clusters/homelab/apps/immich.yaml](https://github.com/cunialino/homelab/blob/main/clusters/homelab/apps/immich.yaml).

| | |
|---|---|
| `immich-server` | the API and web app, port 2283, the only thing that talks to the Ingress |
| `immich-machine-learning` | CPU inference, port 3003, weights on its own 5 GiB volume |
| `immich-valkey` | job queue and cache, Valkey 9 with AOF, 2 GiB |

Originals, thumbnails and preview videos share the `immich-upload` claim: 20 GiB on
`longhorn-wdblack`, `ReadWriteOnce`. Both PVCs carry `kustomize.toolkit.fluxcd.io/prune: disabled`,
and the two Deployments roll with `maxSurge: 0` because a surge pod could not attach a volume the
running pod already holds.

The Ingress uses the `tailscale-stream` proxy class: full-resolution uploads and video streaming
hold connections open far longer than the small class assumes.

## Database

Immich uses the shared CloudNativePG `pg-cluster` — the database is
[infrastructure/configs/postgres/immich.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/configs/postgres/immich.yaml),
the managed role is in `cluster.yaml`, and the credentials are a
[SOPS-encrypted Secret](/utils/secrets/) pair like every other app here.

Two things about that pairing are worth writing down.

**Extensions.** Immich wants `vector`, `cube`, `earthdistance`, `uuid-ossp`, `pg_trgm` and
`unaccent`, and creates most of them in its own migrations. `vector` and `earthdistance` are not
marked `trusted` by PostgreSQL, so a non-superuser cannot install them no matter what it owns — the
`Database` CR declares them `ensure: present` and the operator creates them as superuser. The image
CNPG uses here already ships pgvector 0.8.1, which is inside the range immich accepts.

**VectorChord.** Immich 3 defaults to VectorChord for vector search, and looks for it before it
falls back to plain pgvector. VectorChord has to be preloaded by the Postgres server itself
(`shared_preload_libraries = 'vchord.so'`), which is not something to bolt onto a cluster four other
apps share, so `DB_VECTOR_EXTENSION=pgvector` pins the fallback explicitly. Switching later means a
dedicated instance or an image with vchord built in, plus a reindex of `face_index` and `clip_index`.

The role is deliberately not a superuser. That costs the in-app database backup feature, which needs
`pg_dumpall`; backups belong to whatever scheme the rest of `pg-cluster` uses anyway.

## Machine learning

The container is the plain CPU image — no GPU in this cluster. Two details are load-bearing rather
than stylistic: the Deployment and Service are named `immich-machine-learning` because that is
immich's built-in default ML URL (`http://immich-machine-learning:3003`), so nothing has to be
configured in the admin panel; and `MACHINE_LEARNING_MODEL_REVISION=v2` matches what the upstream
compose file sets for new installs, with `main` kept for legacy ones.

Inference is slow enough that the first library scan takes hours on four cores, so smart search and
face detection are things that finish overnight rather than on demand.
