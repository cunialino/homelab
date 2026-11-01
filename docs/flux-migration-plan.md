# ArgoCD → Flux migration: target state & plan

Scope: `cunialino/homelab`, `cunialino/myai`, `cunialino/crypto-lakehouse`, and the live k3s
cluster (`elcunal/elcungem/elcunhp1/opizero3`).

Status: **in progress.** Flux is installed, follows `main`, and `vikunja`, `ntfy`, `cilium` and
`garage` are Flux-owned. What was actually done, what was verified, and where this document turns out to be
wrong is in [flux-migration-log.md](./flux-migration-log.md) — read it before acting on §2–§6.
§2 remains the **steady state we are aiming at**, written as if Argo never existed. §5–§6 are
the transition, and every piece of transition-only machinery is listed in §6 with an exit
criterion, so none of it quietly becomes permanent.

Shaped against: `fluxcd/flux2-kustomize-helm-example` and `fluxcd/flux2-multi-tenancy`
(default branches, Flux v2.10.0 era), `fluxcd.io` component specs, and the Renovate `flux`
manager docs.

---

## 1. Current state (verified against the live cluster)

**30 Argo `Application`s** from 3 app-of-apps roots (`homelab apps/`, `myai apps/`,
`crypto-lakehouse deploy/apps/`) → ~23 Helm installs + ~20 plain-manifest dirs.
All 3 repos are public → no source credentials needed anywhere.

Feature surface actually in use: multi-source chart+values (18 apps), `CreateNamespace=true`
(25 apps), `ServerSideApply=true` (12), `ignoreDifferences` (1 app, `risingwave`), `sync-wave`
(2 files). **No** sync hooks, ApplicationSets, notifications, commitServer, or admission
webhooks. Mostly mechanical.

**Drift that fires at cutover** (Flux has no manual sync; it always reconciles Git → cluster):

| App | Out-of-sync | Consequence if adopted as-is |
|---|---|---|
| `risingwave` | 18 (everything; namespace empty, health `Missing`) | Flux installs RisingWave |
| `nextcloud` | 19 (2 redis StatefulSets + main Deployment) | disruptive restart |
| `nats` | 1 (`StatefulSet/nats-cluster`) | 3-node rollout |
| `monitoring` | 2 (grafana Deployment + Secret) | low |
| `cert-manager` | 2 (RBAC) | low |
| `openwebui` | 1 (ConfigMap) | low |
| `oxicloud` | 1 (StatefulSet) | low/medium |

Recounted 2026-11-01: **25** Argo Applications left (24 workloads + `root-bootstrap`), 14 homelab
Application files in `apps/`, one Helm release adopted (`descheduler`, log §5.3). The `OutOfSync`
set is the seven above plus `graphiti`, whose diff is the `graphiti-factories` ConfigMap Argo left
behind when it was deleted from Git with `prune: false`. Live state is tracked in
[flux-migration-log.md](./flux-migration-log.md) §1, not here.

---

## 2. Target steady state

### 2.1 homelab (platform repo)

```
homelab/
├── .sourceignore
├── .fluxschema.yml
├── scripts/validate.sh
├── clusters/homelab/                  # ← what flux bootstrap syncs; the whole cluster
│   ├── flux-system/                   #   gotk-components.yaml, gotk-sync.yaml, kustomization.yaml
│   ├── kustomization.yaml             #   lists sources.yaml + infra/* + apps/*
│   ├── sources.yaml                   #   GitRepository: myai, crypto-lakehouse
│   ├── infra/                         #   ONE Flux Kustomization CR per controller / config layer
│   │   ├── cert-manager.yaml  external-secrets.yaml  longhorn.yaml  cloudnative-pg.yaml
│   │   ├── tailscale-operator.yaml  keda.yaml  descheduler.yaml  arc-controller.yaml
│   │   └── eso-store.yaml  tls.yaml  proxy-classes.yaml  postgres.yaml  longhorn-config.yaml
│   ├── apps/                          #   ONE Flux Kustomization CR per application, incl. cross-repo
│   │   ├── nats.yaml  garage.yaml  monitoring.yaml  nextcloud.yaml  vikunja.yaml
│   │   ├── ntfy.yaml  oxicloud.yaml  renovate.yaml  arc-scale-sets.yaml
│   │   ├── myai-ddg-search.yaml  myai-graphiti.yaml  myai-openwebui.yaml
│   │   └── lake-{lakekeeper,arroyo,risingwave,batcher,collector}.yaml   # see §2.2
│   └── dev/batcher-test.yaml          #   NOT listed in kustomization.yaml → stays inert
├── infrastructure/
│   ├── controllers/<name>/            #   dir per controller: namespace + chart source + HelmRelease
│   │   └── {kustomization,namespace,repository,helmrelease}.yaml
│   │   # cert-manager  external-secrets  longhorn  cloudnative-pg
│   │   # tailscale-operator  keda (+ keda-add-ons-http, 2 HRs)  descheduler  arc-controller
│   └── configs/                       #   CRs consumed by those operators, split by dependency
│       ├── secret-stores/             #     was base/eso/{clustersecretstore,bitclustertls}.yaml
│       ├── tls/                       #     was base/cert-manager/cluster-issuer.yaml
│       ├── proxy-classes/             #     was base/tailscale/proxyClass.yaml
│       ├── postgres/                  #     was base/cnpg/*.yaml (Clusters) + secret_*.yaml
│       └── longhorn/                  #     was base/longhorn/{nodes,maintenance,wd_black*}.yaml
└── apps/                              # applications: env-agnostic base + one cluster overlay
    ├── <app>/base/                    #   {kustomization,namespace,repository,helmrelease}.yaml
    │   # nats  monitoring (3 HRs)  nextcloud  oxicloud  renovate  arc-scale-set
    ├── garage/base/  ntfy/base/  vikunja/base/   # plain-manifest apps: no HelmRelease
    └── homelab/                       # this cluster's overlay (stands in for "production")
        └── kustomization.yaml         #   resources: ../<app>/base…  patches: env tweaks
```

Notes on the shape:

* **`flux bootstrap --path=clusters/homelab` writes `clusters/homelab/flux-system/`** — do not
  invent a `bootstrap/` directory; the `bootstrap/` habit is Argo's, not Flux's.
* **`apps/` holds both tools during the transition — keep it that way deliberately.**
  Argo's root app reads `apps/` **non-recursively** (`bootstrap/root-app.yaml` has no
  `source.directory.recurse`), so it only ever sees top-level `apps/*.yaml`, and every Flux file
  lives at `apps/<app>/base/…` or `apps/homelab/…` where Argo cannot see it. The one hard rule:
  **never put a `kustomization.yaml` directly in repo-root `apps/`**, or Argo will try to render
  it as an Application. Each wave is then one greppable swap: delete `apps/<x>.yaml` (Argo does
  not act on the file deletion — its root has `prune: false`) and add `apps/<x>/base/` plus
  `clusters/homelab/apps/<x>.yaml`. Verify in wave 1 that Argo's `root-bootstrap` stays Synced.
* **Single cluster ⇒ one env dir, named after the cluster**, not `production`/`staging`.
  `apps/homelab/kustomization.yaml` is the analogue of the reference's `apps/production/`.
  Per-app overlay dirs are created *only* when an app actually needs a cluster-specific
  patch; until then `apps/homelab/kustomization.yaml` just lists bases.
* **Cross-repo orchestration lives only here** (`flux2-multi-tenancy`: the platform repo owns
  `GitRepository` + sync objects per tenant). App repos never declare what gets deployed.
* `apps/<app>/base/` per the reference example: `namespace.yaml` (explicit `Namespace`, since
  Flux has no `CreateNamespace`), `repository.yaml` (chart source, **co-located in the app's
  own namespace**), `helmrelease.yaml`.
* **Directory-per-unit, not flat files.** `infrastructure/controllers/<name>/`,
  `infrastructure/configs/<layer>/` and `apps/<app>/base/` are kustomize dirs because each is
  the `path:` of exactly one Flux `Kustomization`. The reference example is flat
  (`controllers/cert-manager.yaml`) because it has two controllers; with 8 controllers, 5 config
  layers and ~17 apps, a shared `path:` would let one typo in `vikunja` block a whole layer.
* `clusters/homelab/kustomization.yaml` is built by kustomize and applied by the bootstrap
  `flux-system` Kustomization; the Kustomization CRs it lists then take over. An error in that
  one file blocks everything — hence `scripts/validate.sh` in CI (§2.7).

### 2.2 myai, crypto-lakehouse (app repos)

App definitions only — no cluster wiring, no app-of-apps:

```
myai/apps/{ddg-search,graphiti,openwebui}/base/…
crypto-lakehouse/apps/{lakekeeper,arroyo,risingwave,batcher,collector,runners-scale-set}/base/…
crypto-lakehouse/apps/batcher/overlays/test/          # was deploy/overlays/batcher-test
```

* `crypto-lakehouse/deploy/apps/` **is deleted** — that directory is app-of-apps residue and
  its content reappears as `clusters/homelab/apps/lake-*.yaml` in homelab.
* `deploy/base/<x>/` content moves into `apps/<x>/base/`; existing `kustomization.yaml` files
  (arroyo, batcher) carry over.
* The ephemeral branch-test app: its `Kustomization` CR lives in
  `clusters/homelab/dev/batcher-test.yaml` in homelab, a directory *not* referenced by
  `clusters/homelab/kustomization.yaml`, so it stays inert until `kubectl apply -f`. Same
  manual lifecycle as today, expressed in Flux.
* **The batcher-test overlay breaks as-is.** `deploy/overlays/batcher-test/kustomization.yaml`
  pulls `resources: [../../base/batcher]`. In Argo that resolves because Argo builds from the
  repo root; in Flux the kustomization root is derived from `spec.path`, and while Flux does
  permit `../` (its own docs use `components: [../ingress]`), the exact restriction is worth
  proving per app rather than trusting. The target layout makes the question moot: with
  `apps/batcher/{base,overlays/test}`, the parent reference stays inside `apps/batcher/` under
  any load restriction. Same for `apps/arroyo/base/`, whose `configMapGenerator` reads
  `proto/`, `sql/`, `tables/` subdirectories — move the whole directory, keep
  `disableNameSuffixHash: true` (the register Job's volume name depends on it).
* `myai/apps/openwebui/base/database.yaml` creates a CNPG `Database` in the `cnpg-system`
  namespace. Keep it there (it is myai's database) but make ownership explicit: it belongs to
  myai's Kustomization and must never appear in homelab's `infrastructure/configs/`.

### 2.3 Sync graph

`flux bootstrap` gives `flux-system` → `clusters/homelab`. Everything else is explicit:

```
flux-system  (bootstrap → clusters/homelab/)
  ├─ infra/{cert-manager, external-secrets, longhorn, cloudnative-pg,
  │        tailscale-operator, keda, descheduler, arc-controller}
  │        wait: true; HelmRelease keda-add-ons-http dependsOn HelmRelease keda
  ├─ infra/eso-store       dependsOn: infra/external-secrets
  ├─ infra/tls             dependsOn: infra/cert-manager
  ├─ infra/proxy-classes   dependsOn: infra/tailscale-operator   # backs 10 Ingresses
  ├─ infra/postgres        dependsOn: infra/cloudnative-pg + infra/eso-store
  ├─ infra/longhorn-config dependsOn: infra/longhorn
  └─ apps/*                dependsOn: the specific infra/* layers above, plus app-to-app below
```

Per-app `dependsOn` edges (from grep across the 3 repos — these are what break if you flatten):

| App | dependsOn | Cross-repo? |
|---|---|---|
| `monitoring`, `garage`, `nextcloud`, `vikunja`, `renovate` | `infra/eso-store` (`bitwarden-secretsmanager` ClusterSecretStore) | no |
| `nextcloud`, `oxicloud`, `vikunja` | `infra/postgres` | no |
| every tailed Ingress | `infra/proxy-classes` | no |
| `openwebui` (myai) | `infra/postgres`, `infra/eso-store` | **yes** |
| `lakekeeper` | `infra/postgres` (`pg-cluster-rw/ro.cnpg-system` + its ExternalSecrets) | **yes** |
| `arroyo` | `infra/postgres`, `nats`, `lakekeeper` | **yes** |
| `risingwave` | `infra/postgres`, `garage`, `lakekeeper` | **yes** |
| `batcher`, `collector` | `nats`, `risingwave`/`lakekeeper` | **yes** |
| `arc` scale-sets | `arc-controller` | yes (crypto-lakehouse scale-set) |
| Longhorn config CRs (nodes, backups, PDB-ish) | `infra/longhorn` | no |

`infra/postgres` uses `wait: true` + `healthChecks` on `Cluster/postgres` so consumers block on a
genuinely healthy cluster instead of erroring-and-retrying; operator layers get `healthChecks` on
their Deployments. `dependsOn` names **Flux objects**, which is why the config layers are separate
Kustomizations rather than one `infra-configs` bucket. `Kustomization` and `HelmRelease` both
support `dependsOn` (optionally a CEL `readyExpr`) and `healthChecks` — confirmed in the current
CRDs.

Why one `Kustomization` CR per unit instead of the reference's 3 coarse layers: with ~25 units
across 3 repos and the edges above, per-unit objects give (a) blast-radius isolation and
(b) precise `dependsOn` rather than one blanket edge from every app to `infra-configs`. Plain
Flux, not an extension. See §2.8 for what the official example now does instead.

### 2.4 Anatomy: one infra controller

```yaml
# infrastructure/controllers/cert-manager/helmrelease.yaml
apiVersion: v1
kind: Namespace
metadata: {name: cert-manager}
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository                        # verified: quay.io/jetstack/charts/cert-manager
metadata: {name: cert-manager, namespace: cert-manager}
spec:
  interval: 24h
  url: oci://quay.io/jetstack/charts/cert-manager
  ref: {tag: v1.21.2}                      # pinned tag, NOT semver — see §5 Renovate
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata: {name: cert-manager, namespace: cert-manager}
spec:
  interval: 1h
  retryInterval: 2m
  timeout: 5m
  releaseName: cert-manager                # pinned, see §3.2
  chartRef: {kind: OCIRepository, name: cert-manager}
  install: {strategy: {name: RetryOnFailure}}
  upgrade: {strategy: {name: RetryOnFailure}}
  values:                                  # was base/<app>/values.yaml → inline, §2.6
    crds: {enabled: true, keep: false}
```

Shown as one block for readability; in the tree these are separate files in the same directory
(`namespace.yaml`, `repository.yaml`, `helmrelease.yaml`) listed by that directory's
`kustomization.yaml`, which is what makes it the `path:` of exactly one Flux `Kustomization`.

### 2.5 Chart sources: OCI where verified

`OCIRepository` avoids polling a multi-MB index and is what the reference example now uses.
Probed against the registry APIs today:

| Chart | OCI | Verified URL |
|---|---|---|
| kube-prometheus-stack 92.10.1 | ✅ | `oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack` |
| loki 7.3.0 | ✅ | `oci://ghcr.io/grafana/helm-charts/loki` |
| cert-manager v1.21.2 | ✅ | `oci://quay.io/jetstack/charts/cert-manager` |
| external-secrets 2.10.0 | ✅ | `oci://ghcr.io/external-secrets/charts/external-secrets` |
| cloudnative-pg 0.29.1 | ✅ | `oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg` |
| nextcloud 9.2.2 | ✅ | `oci://ghcr.io/nextcloud/helm/nextcloud` |
| gha-runner-scale-set(-controller) 0.14.2 | ✅ | `oci://ghcr.io/actions/actions-runner-controller-charts/…` |
| renovate | ✅ (already OCI) | `oci://ghcr.io/renovatebot/charts/renovate` |
| descheduler 0.36.0 | ❌ | probed 2026-11-01: no OCI distribution anywhere plausible (`registry.k8s.io/descheduler/charts/…`, `registry.k8s.io/descheduler/…`, `registry.k8s.io/charts/…`, `ghcr.io/kubernetes-sigs/charts/…` all absent) → stays `HelmRepository` + `spec.chart.spec.version` |
| longhorn, keda, keda-add-ons-http, nats, nack, alloy, tailscale-operator, risingwave, arroyo, lakekeeper, open-webui | ❓ | keep `HelmRepository`; probe before switching |

A 404 above only means *that guessed path* is absent — re-probe upstream before deciding.
Switching an adopted release from `HelmRepository` to `OCIRepository` does not change release
identity (name/namespace are what matter), so it is safe to do during adoption rather than in
a second pass.

### 2.6 Values policy: inline

Canonical is `HelmRelease.spec.values` inline, with environment differences applied as a
**patch on the HelmRelease** in the env dir (exactly what
`apps/production/podinfo-values.yaml` does in the reference), or via `Kustomization.spec.patches`.

This is now unambiguously the right call here: every values file in the three repos is small
— largest is `base/monitoring/values.yaml` at 156 lines, then `openwebui` 132, `risingwave`
129, `renovate` 116, `alloy` 111 — so nothing justifies a `valuesFrom` indirection.

Consequences worth stating up front:

* `base/*/values.yaml` files **disappear**; their content moves into the `HelmRelease`.
  Renovate's `flux` manager reads inline HelmRelease values the way `helm-values` does, so
  image/tag coverage is not lost.
* `HelmRelease.spec.valuesFrom` (ConfigMap in the release's own namespace) stays available for
  a future app whose values genuinely must be shared between releases. Not used at the start.
* Chart + values from two different repos (the OxiCloud case: chart lives at
  `charts/oxicloud` in upstream's git) becomes `GitRepository` + `HelmChart` with
  `sourceRef`, values inline on the HelmRelease. No ConfigMap, no `ArtifactGenerator`.

### 2.7 Repo hygiene (present in the reference repos, missing from plan v1)

* `.sourceignore` — keep docs, `eval/results/**` (myai has ~600 result files), `.direnv`,
  `target/`, `spark-warehouse/` out of the artifacts source-controller unpacks.
* `.fluxschema.yml` — IDE completion/validation for the Flux CRs.
* `scripts/validate.sh` — `flux check --pre` plus a `kustomize build` over every directory
  holding a `kustomization.yaml`, run in CI on every PR (all three repos).
* Every `HelmRelease`: `interval`, `timeout`, `install.strategy/upgrade.strategy:
  RetryOnFailure` — and **no `retryInterval`**. That field belongs to `Kustomization` and the
  source kinds, not `HelmRelease`; SSA rejects it with `.spec.retryInterval: field not declared
  in schema`, which is how this plan line was caught (verified against
  `helmreleases.helm.toolkit.fluxcd.io` on the cluster, helm-controller v1.6.5).
* Drop `image-reflector-controller` / `image-automation-controller` at install time — Renovate
  owns version bumps and Flux image automation would fight it.

### 2.8 One deliberate deviation, flagged

The reference example's `clusters/production/artifacts.yaml` now uses **`ArtifactGenerator`**
(`source.extensions.fluxcd.io/v1beta1`) with `pathPattern` to auto-discover
`apps/{app}/envs/{env}` and emit one `ExternalArtifact` per app, and to compose a chart with
values from another repo. Tempting, but:

* it is a `v1beta1` **extension** API and `ExternalArtifact` as a `sourceRef` is documented
  behind `--feature-gates=ExternalArtifact=true`, which has to be injected into the controller
  Deployments via a bootstrap customization patch;
* Renovate's `flux` manager documents HelmRelease / GitRepository / OCIRepository /
  Kustomization / system-manifest support only — **no `ArtifactGenerator` or
  `ExternalArtifact`**. Since Renovate is this cluster's update engine and runs on ARC runners
  in this cluster, that is a real regression;
* with ~25 apps, hand-written per-app `Kustomization` CRs are cheap and greppable.

**Decision: hand-written per-app Kustomizations + `GitRepository` sources.** Revisit
`ArtifactGenerator` only after Flux has been stable for a while and Renovate gains support.
This is the one place where "the official example does it" and "what we should do" differ, so
it is recorded rather than left implicit.

### 2.9 Other deliberate deviations

* **Secrets: SOPS + age, committed to Git.** Reverses this section's original "No SOPS".
  Verified end-to-end on vikunja (`apps/vikunja/base/secret-probe.yaml`, now on `main` after the
  pilot branch was squashed):
  kustomize-controller decrypts before applying, strips the `sops:` recipient block on the way
  (so a `Secret` is not rejected by strict decoding), and a missing key fails loudly —
  `Ready=False BuildFailed: secrets "sops-age" not found` — without touching anything already
  applied. Drift correction survives the move: a hand-patched Secret was restored on the next
  reconcile, because kustomize-controller re-applies every `interval`, not only on a new
  revision.

  Mechanics that are easy to get wrong: `encrypted_regex: ^(data|stringData)$` (metadata must
  stay plaintext, and a kustomize patch injecting a plaintext field matching that regex breaks
  decryption of the whole file); the decryption `Secret` must live in the namespace of the
  *Kustomization object*, not the target — one `sops-age` in `flux-system` therefore covers
  every sync in this layout — and its data key name must end in `.agekey`. `spec.decryption`
  is still required per Kustomization even with the controller's `--sops-age-secret` fallback,
  since `ImportKeys` returns early when it is nil. `.sops.yaml` is CLI-side only: the
  `GitRepository` ignore keeps it out of the artifact and the controller reads recipients from
  each file.

  Accepted costs: **`flux diff` is blind to encrypted values** — a plaintext edit reports drift
  while a changed encrypted value exits 0 silently, with or without `SOPS_AGE_KEY_FILE` (the
  CLI masks sops data deliberately). The phase-3 ritual of "run `flux diff` and read it" is
  therefore not a check on secret content; verify those with
  `sops -d <file> | kubectl apply --dry-run=server -f -`. And the age key cannot come from Git,
  so it joins the deploy key as a manual bootstrap artifact plus an offline backup.

  **Not yet reconciled with the rest of this document.** The *mechanism* is settled: secret
  content goes into Git as age-encrypted `Secret`s. What is still undecided is whether ESO and
  Bitwarden retire outright. ExternalSecrets are therefore still assumed in
  §2.1 (`infrastructure/configs/secret-stores/`), §2.3 (`infra/eso-store` and the per-app
  `dependsOn` rows), §4 (waves 2 and 2b) and §6. Deciding that SOPS replaces ESO outright
  deletes a whole layer of `dependsOn` edges and removes Bitwarden from the apps' runtime path —
  which is worth weighing on its own terms: an `externalsecret/vikunja` refresh failure against
  `bitwarden-sdk-server` is a real, observed event. Until that call is made, both pipelines
  exist and only the probe demonstrates the SOPS one.
* **No `apps/<app>/envs/<env>` per app.** One cluster; the overlay dir is per-cluster
  (`apps/homelab/`), created only when an app needs patching. Full staging/prod machinery for
  a single cluster would be cargo cult.

---

## 3. Migration hard problems

### 3.1 Helm ownership adoption (the big one)

ArgoCD **renders** Helm templates and applies them as plain manifests; it creates **no** Helm
release storage. Verified live:

```
$ kubectl -n monitoring get secret -l owner=helm        # No resources found
$ kubectl -n keda get deploy keda-operator -o jsonpath='{.metadata.annotations}'
  argocd.argoproj.io/tracking-id: keda:apps/Deployment:keda/keda-operator   # no meta.helm.sh/*
$ ... '{.metadata.managedFields[*].manager}'            # argocd-controller/Apply  k3s/Update
```

So a release has to be **adopted** before `helm-controller` will manage it, and the alternative —
letting Helm delete and recreate — would take down Longhorn, CNPG and the lakehouse. The original
plan assumed that meant stamping every object by hand first. On this cluster it does not.

**Take-ownership is on by default, and it worked.** helm-controller v1.6.5 ships Helm 4 and
exposes `install.disableTakeOwnership`, **defaulting to `false`**: Helm 4 adopts pre-existing
objects during `install` and writes the ownership metadata itself. So the first move is simply to
apply the `HelmRelease` and read what happens. On `descheduler` (2026-11-01) that was
`InstallSucceeded … release kube-system/descheduler-affinity-sync.v1`, and afterwards:

* `sh.helm.release.v1.descheduler-affinity-sync.v1` exists — release storage, which Argo never
  created, now does;
* `meta.helm.sh/release-name`, `meta.helm.sh/release-namespace` and
  `app.kubernetes.io/managed-by=Helm` on all five objects, cluster-scoped ones included;
* every object `uid` unchanged and `generation` unchanged — nothing deleted, nothing restarted,
  CronJob still completing on schedule;
* no `--force-conflicts` was needed, and none exists to pass: the CRD has
  `install.serverSideApply` but **no** `forceConflicts`, so the "take-ownership requires forced
  conflicts" caveat (helm/helm#31510) did not bite on CSA-owned objects.

That turns §3.1 from ~300 annotations into one `apply` per release — *for releases whose live
state already equals the chart render*. Two conditions decide that, and both are checked before
applying, not after:

1. `kubectl diff -f <chart render>` shows **no spec differences**. Where it does — the §1 list:
   `nextcloud`, `nats`, `monitoring`, `openwebui`, `oxicloud`, `cert-manager` — take-ownership
   writes the chart's state, i.e. it *forces* the drift and can restart pods. Resolve the drift
   first, or adopt those with `ssa: IfNotPresent` (§3.3).
2. Nothing mutates the objects out of band. Operator-owned CRs (CNPG `Cluster`, Longhorn
   volumes/nodes) are exactly where Helm becoming the field manager can undo controller-set
   fields; those keep the manual route plus `ssa: Merge`.

**The guard that has to stay on both paths: `install.strategy: RetryOnFailure`.** Per
helm/helm#31333 a *failed* install that is subsequently uninstalled can destroy the resources it
failed to take over. A failed HelmRelease is therefore repaired in place — never `helm uninstall`-ed,
and never deleted without first checking which objects it claimed
(`kubectl get <kind> -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}'`).

`scripts/helm-adopt.sh <release> <namespace> <rendered.yaml>` survives as the fallback for the two
cases above. It prints one row per object with its current `meta.helm.sh/*` state and
`managedFields` managers, then the commands (`-a` to apply). Two things it made concrete: the
`app.kubernetes.io/managed-by=Helm` label is already on every object (Argo applies the chart's
rendered labels verbatim) so only the two annotations are ever missing, and cluster-scoped objects
still need `release-namespace` set but must be annotated without `-n`.

This step is identical no matter how the repo tree is shaped — which is exactly why going
straight to the canonical layout (§2) costs no extra cluster risk.

### 3.2 Release names are baked into object names

Live evidence: `prometheus-grafana` / `prometheus-kube-prometheus-operator` (release
`prometheus`), `nats-cluster` (release `nats-cluster`), `descheduler-affinity-sync` (release =
Application name), `cnpg-stack-cloudnative-pg` (release `cnpg-stack`).

Flux's rule (`helm-controller/api/v2` `GetReleaseName()`):

```go
if Spec.ReleaseName != ""     { return Spec.ReleaseName }
if Spec.TargetNamespace != "" { return TargetNamespace + "-" + Name }
return Name
```

So: **pin `spec.releaseName` to the historical value** and keep `metadata.name` in the clean
canonical style (HR `kube-prometheus-stack`, `releaseName: prometheus`). The Argo fossil then
survives only inside cluster object names, where changing it means reinstalling anyway.

Also: **never set `spec.targetNamespace`** (it silently prefixes the release name and renames
every object), and never change `releaseName` after adoption — the controller uninstalls the
old release first.

### 3.3 SSA field handover

Today's manager is `argocd-controller/Apply`; `kustomize-controller` applies as its own.
Per-field SSA is last-writer-wins so handover normally succeeds silently, but **atomic lists**
(`containers`, `env`, `tolerations`) cannot have two managers — that is where it bites.

Verified on `descheduler` (2026-11-01), which is the *other* case — Argo applied it with
client-side apply (`argocd-controller|Update` plus `kubectl.kubernetes.io/last-applied-configuration`,
not `Apply`): `kubectl apply --server-side --dry-run=server --field-manager=kustomize-controller`
took all five objects with no conflict and no `--force-conflicts`, even the CronJob, whose
`managedFields` also list `k3s|Update`. A CSA owner is not a competing SSA manager, so the
atomic-list problem needs **two** SSA managers to appear; it does not bite on CSA-to-SSA
handover. Run the same dry-run probe per app — it costs one command and no writes. Lever
is an annotation set in the Git manifests:

| `kustomize.toolkit.fluxcd.io/ssa` | Meaning | Use |
|---|---|---|
| `Override` (default) | reconcile to Git | steady state |
| `IfNotPresent` | apply only if absent; never touch what exists | adopt the §1 drifted apps without forcing a restart, then remove |
| `Merge` | keep other tools' added fields | CNPG/Longhorn CRs mutated by their operators |

`Kustomization.spec.force` is **not** an ownership switch (it recreates on immutable-field
changes); leave it off.

---

## 4. Phases

Each phase revertible; Argo keeps running until Phase 6.

**Phase 0 — decide.** Remaining open items in §9.

**Phase 1 — install Flux alongside Argo; build the canonical tree empty.**
```bash
flux bootstrap github --owner=cunialino --repository=homelab --branch=main \
  --path=clusters/homelab --personal \
  --components=source-controller,kustomize-controller,helm-controller,notification-controller
```
Then commit `clusters/homelab/`, `infrastructure/`, `apps/` skeletons with **zero workloads**,
plus `.sourceignore`, `.fluxschema.yml`, `scripts/validate.sh`, and CI running validate.sh on
all three repos. `flux-system` is now self-managing and nothing else is touched.
Rollback: `flux uninstall --silent`.

**Done differently.** `flux bootstrap` was never run. `flux install` (nixpkgs, v2.9.6) deployed
the four core controllers with no image automation, and `clusters/homelab/flux-system/gotk-sync.yaml`
was written by hand and `kubectl apply`-ed — so the controllers are **undeclared**.
`ref.branch` was flipped to `main` on 2026-11-01 (`46ccd81`, procedure in log §5.1), but
`gotk-components.yaml` still does not exist, so Flux is *still* not self-managing and nothing
bumps Flux itself. `.sourceignore`, `.fluxschema.yml` and
`scripts/validate.sh` were never created: phase 1 ended as "start adopting", not "harden the repo".

**Phase 2 — resolve drift, freeze Argo.** Sync (or amend Git for) the 7 `OutOfSync` apps, then
set `automated.enabled: false` on the 3 roots and on every app slated to move.

**Partly done, and it had to happen on the live object.** `root-bootstrap` was
`automated: {enabled: true, selfHeal: true}`, and an automated root *recreates* any Application
missing from `apps/` — orphaning an Application without freezing the root puts a second writer
straight back on it. It is now `enabled: false`, live and in `bootstrap/root-app.yaml`. The
`myai` and `crypto-lakehouse` roots are untouched and no drift was resolved (`monitoring` is
still `OutOfSync`). Children keep their own sync policies so nothing workload-facing stopped,
but while the root is frozen, edits to `apps/*.yaml` need a manual root sync — including
Renovate's two `custom.regex` managers for `apps/arc.yaml` and `apps/renovate.yaml`.

**Phase 3 — wave-by-wave adoption, straight into the canonical layout.** Per app: write
`infrastructure/**` or `apps/<app>/base/**` + its `clusters/homelab/apps/<x>.yaml`; run
`flux diff kustomization <x> --path <spec.path> --kustomization-file <the CR file>` and read it
(both flags are required — bare `flux diff kustomization <x>` fails with
`invalid resource path ""`); adopt (§3.1) with `ssa: IfNotPresent` on anything still drifted;
apply; `flux reconcile`; confirm Ready + no restarts (`kubectl -n <ns> get pods -w` / check
`restarts` and `AGE`); then delete the Argo Application with `--cascade=orphan`.

Two things the vikunja pilot changed about that checklist. Adopting a CSA-managed object bumps
`metadata.generation` (14 → 15) with **no** rollout, so generation is not evidence that Flux
touched something — the pod `uid` and the ReplicaSet hash are. And for apps whose content is
already in sync, plain-manifest adoption needed no `ssa: IfNotPresent` at all:
`kustomize-controller | Apply` simply joined `argocd-controller | Update` in `managedFields`
and left `argocd.argoproj.io/tracking-id` in place. That annotation is inert once the
Application is gone, so removing it is cleanup, not a prerequisite.

✅ = adopted and verified in the first pass; evidence in the log.

| Wave | Apps | Rationale |
|---|---|---|
| 1 | `ntfy` ✅, `ddg-search` (cross-repo, not started) | only app with no secret and no operator; drills adoption + the `apps/<app>/base` wiring with the smallest possible blast radius |
| 1b | `cilium` ✅ — LB IP pool only, **was not in the original wave list** | cluster-scoped and trivially in sync; the CNI itself is installed with `cilium install`, outside Git either way |
| 2 | `descheduler` ✅ — first Helm release, adopted by take-ownership with no annotations at all — then `external-secrets` + `infra/eso-store`, `cert-manager` + `infra/tls`, `tailscale-operator` + `infra/proxy-classes` | establishes the `infra/*` pattern and the config-layer `dependsOn` edges the rest of the cluster needs |
| 2b | `vikunja` ✅, `garage` ✅ — both still ESO-backed, and neither has `dependsOn` on `infra/eso-store` because that layer does not exist as a Flux object yet | plain manifests, but both carry ExternalSecrets, so they must follow `infra/eso-store` |
| 3 | `cloudnative-pg` → then `infra/postgres` (Clusters + their ExternalSecrets) | operator first; verify `pg-cluster` healthy before its CRs move |
| 4 | `keda`(+`keda-add-ons-http`), `nats`, `arc-controller`, both `arc` scale-sets | stateful-adjacent; ARC is your CI, keep one runner working |
| 5 | `monitoring` (3 HRs), `renovate`, `nextcloud`, `oxicloud`, `openwebui`, `graphiti` | biggest values files, cross-repo (myai) wiring proven here |
| 6 | `longhorn` | storage; last, or intentionally left on Argo |
| 7 | `lakekeeper`, `risingwave`, `arroyo`, `batcher`, `collector`, `batcher-test` | the whole crypto-lakehouse repo, after its homelab deps are on Flux |

Two rules the wave order is built around:

* **`dependsOn` referencing a `Kustomization` that does not exist yet blocks forever**, so a wave
  may only reference `infra/*` layers from an earlier wave. Where a dependency already exists in
  the cluster but not yet in Flux (e.g. the ProxyClasses backing wave 1's Ingresses), ship wave 1
  **without** that `dependsOn` and add it in wave 2 when `infra/proxy-classes` lands.
* Renovate and ARC run *on* this cluster: migrate them late, and never in the same wave as
  something that could break the runners.

**Phase 4 — Renovate.** See §5.

**Phase 5 — replace what Argo gave you.** Delete the `argocd` tailscale Ingress and reclaim
`argocd.tail2f38ea.ts.net`. Decide UI story *before* deleting Argo: `flux get all -A`,
`flux diff`, or Flux Operator + its web UI. Rewrite `README.md` bootstrap instructions,
`docs/content/cicd/_index.md`, `docs/content/cicd/argocd/_index.md` → `flux/`. Record resource
before/after in `docs/content/monitoring/`: Argo here is 6 workloads pinning 4.5 CPU / 4.5 Gi
of limits per replica.

**Phase 6 — decommission Argo.**
1. `grep -rn "argocd" base/ ../myai/base ../crypto-lakehouse/deploy` → clean.
2. Test `kubectl -n argocd delete application --cascade=orphan <canary>` on a wave-1 app
   **first** — Argo's finalizer cascade-deletes managed resources; orphaning (or removing the
   `argocd` finalizer) is what keeps the cluster alive. Never `--all` blind.
3. Delete the remaining Applications, then the Argo leftovers: `apps/*.yaml` (the Application
   files), `bootstrap/root-app.yaml`, `base/` (fully translated by now — see §6), `base/argocd/`,
   and the `repo-homelab` ExternalSecret.
4. `kubectl -n argocd delete ns argocd`.

---

## 5. Renovate

Current `base/renovate/values.yaml` enables `argocd` with
`managerFilePatterns: ["/^(deploy\\/)?apps\\/.+\\.ya?ml$/"]`, plus `helm-values` patterns
covering `base/**/values*.yaml`, plus two `custom.regex` managers hardcoded to `apps/arc.yaml`
and `apps/renovate.yaml`.

Target:

```json
"enabledManagers": ["flux", "kubernetes", "docker-compose", "dockerfile", "cargo", "custom.regex"],
"flux": { "managerFilePatterns": ["/^clusters\\/.+\\.ya?ml$/", "/^infrastructure\\/.+\\.ya?ml$/", "/^apps\\/.+\\.ya?ml$/"] }
```

* **Drop `helm-values`**: §2.6 removes the standalone values files, and the `flux` manager
  reads inline HelmRelease values the same way. Keep `kubernetes` for raw image refs in
  `apps/*/base/*.yaml` (vikunja, ntfy, garage, collector, batcher).
* **HelmRepository/OCIRepository must be visible in the same scanned repo as the HelmRelease,
  with explicit `metadata.namespace` on both** — Renovate never infers namespaces, and it links
  `HelmRelease` → source only when both parse. This is exactly why §2.1 co-locates
  `repository.yaml` inside each app's base dir, including in the app repos. For sources defined
  elsewhere, use `flux.registryAliases`.
* **Pin `ref.tag` (or `spec.chart.spec.version`) explicitly** — never `ref: semver:`, which
  Renovate cannot bump. That is the price of keeping Renovate (rather than Flux image
  automation) as the update engine, and it's the right price.
* Move the two `custom.regex` managers' `managerFilePatterns` to the new ARC / Renovate
  manifest paths.
* `gotk-components.yaml` (Flux itself) is bumped by the `flux` manager, but only if it keeps
  the `flux bootstrap`-generated header — and Renovate cannot know about custom bootstrap
  flags, so keep the file generated rather than hand-edited.
* Verify before merge: `renovate --dry-run --log-level=debug` per repo, grep for `flux`
  manager extractions; confirm the HR versions are found before trusting a cron cycle.

---

## 6. Migration scaffolding & exit criteria

Everything in this table is transition-only. **If a row outlives phase 6, the migration
failed quietly.**

| Scaffold | Why | Exit |
|---|---|---|
| `meta.helm.sh/*` adoption annotations | Argo left no Helm release storage (§3.1) | never removed — becomes normal Helm ownership. Helm writes them itself on the take-ownership path, so most releases will never carry hand-made ones |
| `scripts/helm-adopt.sh` | fallback for the releases take-ownership must not force (§3.1: drifted apps, operator-mutated CRs) | delete in phase 6 if every remaining release went through the default path |
| `argocd.argoproj.io/tracking-id` removal | Argo's tracker | never — deleted in phase 6 |
| `HelmRelease.spec.releaseName` pinned | historical Argo release names (§3.2) | permanent (renaming = reinstall); must never be *added* to a new app |
| `kustomize.toolkit.fluxcd.io/ssa: IfNotPresent` | adopt drifted objects without restarting | remove per app in the same wave, once Ready with no diff |
| `Kustomization.spec.deletionPolicy: Orphan` | safe rollback while Argo still exists | revert to default `MirrorPrune` in phase 6, except stateful apps where orphaning is deliberately permanent (Longhorn, CNPG) |
| Argo `apps/`, `myai/apps/`, `crypto-lakehouse/deploy/apps/` frozen | parallel operation | deleted phase 6 |
| `base/` directory | source of values/manifests during translation | deleted once every app's content lives in `infrastructure/` or `apps/` |
| `apps/homelab/` overlay listing bases | stands in for a real env dir | permanent, but stays thin: an entry only when an app needs a patch |
| `clusters/homelab/dev/` (unreferenced) | keeps `batcher-test` inert | permanent by design |
| `secret/sops-age` in `flux-system` | decrypts SOPS-in-Git secrets (§2.9) | permanent, but **can never come from Git** — bootstrap artifact alongside the deploy key, with an offline backup |
| `apps/vikunja/base/secret-probe.yaml` + `decryption` on the vikunja Kustomization | reference implementation proving the §2.9 pipeline | deleted once the ExternalSecrets question in §2.9 is settled |

---

## 7. Rollback

Deleting a Flux object garbage-collects what it created (default `deletionPolicy: MirrorPrune`),
so set the policy *before* you need it rather than pulling finalizers afterwards:

```bash
flux suspend kustomization <app>
flux delete kustomization <app> --silent            # Orphan policy → workloads survive
kubectl -n <ns> label <kind> <name> app.kubernetes.io/managed-by-
kubectl -n <ns> annotate <kind> <name> meta.helm.sh/release-name- meta.helm.sh/release-namespace-
```

Then re-apply the Argo Application: Argo re-adopts via `tracking-id` and returns Synced without
recreating pods. This stays true for every app until phase 6 step 3.

---

## 8. Honest trade-offs

**Given up:** the Argo UI and click-to-sync; per-resource sync (Flux reconciles a whole
Kustomization/HelmRelease); `automated: false` as a clean manual gate — Flux's equivalent is
`suspend: true`, clunkier and easy to leave on; Argo's diff viewer (`flux diff` is narrower).

**Gained:** 3–4 small controllers instead of 6 workloads / 4.5 CPU + 4.5 Gi of limits, and no
central cache that grows with the cluster; Git as the only writer; explicit `dependsOn` +
`healthChecks` replacing implicit wave ordering; `ignoreDifferences` handling of
operator-mutated CRs without whack-a-mole; OCI chart sources; a repo topology that matches the
official Flux reference layouts, so future readers (and future-you) find nothing homelab-isms
to decode.

**Not free:** the canonical restructure touches all three repos in the same motion, so wave 5–7
diffs are larger than a 1:1 port would have been. §3.1 was the stated risk and has shrunk a great
deal (take-ownership, verified in log §5.3), but it moved rather than disappeared: the remaining
danger is concentrated in the six drifted releases and in operator-mutated CRs, where adoption
*does* write live state.

---

## 9. Open decisions

1. **`risingwave` is currently not deployed at all** (empty namespace, health `Missing`).
   Intentional? If it stays off, its Flux `Kustomization` needs `suspend: true` from day one.
2. **Drift**: sync the 7 `OutOfSync` apps in Argo first (recommended), or accept the restarts
   adoption would otherwise cause?
3. **Longhorn**: wave 6, or left on Argo indefinitely? Argo and Flux coexist per-app.
4. **UI**: `flux` CLI only, or add Flux Operator + web UI? Decide before phase 5.
5. **`notification-controller`**: installed but idle, or wired to the existing `ntfy` for
   sync/health alerts?
6. ~~Confirm I should proceed with phase 1.~~ Phase 1 happened as `flux install` plus a
   hand-written `gotk-sync.yaml`, and its `ref.branch` now points at `main` (log §5.1). The
   open half is declaring the controllers: `flux bootstrap` with the **nixpkgs 2.9.6 CLI** — a
   newer CLI silently upgrades the running install as a side effect — or `flux install --export`
   from the same binary into `clusters/homelab/flux-system/gotk-components.yaml`. Until then
   Flux is unmanaged and Renovate has no `gotk-components.yaml` to bump.
7. ~~Hold `origin/flux-migration` until the sync object applies on `main`.~~ Condition met
   2026-11-01 15:30Z (`flux-system` applied `main@sha1:46ccd81`, ref unchanged): delete it with
   `git push origin --delete flux-migration`.
