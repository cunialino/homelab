# Flux migration — session log (vikunja → ntfy/cilium/garage, SOPS+age)

Handoff record of the working session that produced the first four Flux adoptions.
Companion to [flux-migration-plan.md](./flux-migration-plan.md), which stays the
forward-looking document; this one records what was actually done and verified on the
live cluster, and what the plan got wrong.

Provenance: pi session `01a187b1-8273-7363-aea2-047e720dbf6a`, worktree
`~/builds/homelab-flux` (branch `flux-migration`, later rebased onto `main` by hand).
Raw transcript: `~/.pi/agent/sessions/--home-elia-builds-homelab-flux__/2026-10-29T12-45-19-860Z_01a187b1-8273-7363-aea2-047e720dbf6a.jsonl`.
State below was checked at 2026-11-01T10:35Z, except the sync ref, which moved to `main` at
13:55Z and is described in §5.1.

---

## 1. Live cluster state right now

| Thing | State |
|---|---|
| Flux | v2.9.6 (nixpkgs), installed with `flux install` — 4 core controllers, **no image automation**, **not declared in Git** |
| `flux-system` GitRepository | `https://github.com/cunialino/homelab.git`, **`ref.branch: main`** since `46ccd81` (§5.1) |
| Kustomizations | `flux-system`, `vikunja`, `ntfy`, `cilium`, `garage` — all `Ready`, all applied `main@46ccd81`. Re-verified 15:30Z after the node incident (§6): `spec.ref.branch` still `main`, `suspend` unset, so the flip is converged, not merely applied once |
| Argo Applications deleted | `vikunja`, `ntfy`, `garage`, `cilium` — `--cascade=orphan`, no finalizers present |
| `root-bootstrap` | `automated: {enabled: false}` live **and** in `bootstrap/root-app.yaml` (plan phase 2) |
| Remaining Argo Applications | 26 = 25 workload apps + `root-bootstrap`. One of them, `descheduler-affinity-sync`, is now also Flux-owned and **still an Argo Application with `prune`+`selfHeal`** — the orphan step is pending, so two engines see it (§5.3) |
| SOPS | age keypair live; `secret/sops-age` in `flux-system` (data key `age.agekey`); `.sops.yaml` committed; probe Secret `vikunja/vikunja-sops-probe` reconciled |
| age private key | `~/.config/sops/age/keys.txt` (0600) + Bitwarden (user-confirmed) |
| Secret **content** migration | **none.** Only ExternalSecret manifests moved with their apps. All 21 ExternalSecrets still pull from `bitwarden-secretsmanager` |
| Helm-ownership adoption (§3.1) | **first release adopted**: `descheduler`, by Helm 4 take-ownership, zero manual annotations (§5.3) |

Untracked debris in `~/builds/homelab`, not from this session: `aws_cli.yaml` (risingwave
debug pod, references `secretKeyRef`, no plaintext), `docs/incidents/`.

## 2. What the adoptions look like

Per app, one commit: `base/<app>/` → `apps/<app>/base/` + `clusters/homelab/apps/<app>.yaml`
listed in `clusters/homelab/kustomization.yaml`. The Argo Application file was deleted in a
separate commit after the live Application was orphaned.

```
apps/<app>/base/{kustomization,namespace,…}.yaml   # explicit Namespace: Flux has no CreateNamespace
clusters/homelab/apps/<app>.yaml                   # interval 30m, prune: true, deletionPolicy: Orphan,
                                                   # wait + healthChecks on the Deployment where meaningful
```

No app has `dependsOn`: `infra/eso-store` and `infra/postgres` do not exist as Flux objects
yet, and a `dependsOn` on a missing object blocks forever (plan §4 wave-1 rule, confirmed).

Pre-flight that actually caught things, per app:

```bash
kubectl kustomize apps/<app>/base                       # renders?
kubectl diff -f <rendered>                              # spec-identical to live?
kubectl apply --dry-run=server -f <rendered>            # API accepts it?  <-- kubectl diff alone missed a real bug
```

Verification that adoption was non-disruptive — **pod `uid` and ReplicaSet hash**, not
`metadata.generation`:

```
ntfy    RS 5596ff8dd6 (Oct 7)   garage  RS 64c5c9777f (Oct 16)   vikunja RS 6586d74bbb (Oct 16)
→ no new ReplicaSet anywhere, no rollout
```

Orphan deletion evidence: pod/deploy/PVC/ES/Service/ConfigMap/Ingress/IPPool **UIDs identical
before and after**; garage PVC stayed `Bound` to the same volume and kept VIP `192.168.0.200`;
`lan-vip-pool` UID unchanged; `flux diff` clean for all four afterwards.

## 3. Corrections to the plan (each verified, not inferred)

1. **`spec.prune`, not `spec.pruning`** (`pruning` is v1beta1/Argo naming — I hit this live:
   strict decoding rejects the old field). `deletionPolicy` governs only *Kustomization
   deletion*; `prune` governs objects removed from Git.
2. **Per-object PVC protection is `kustomize.toolkit.fluxcd.io/prune: disabled`**, which
   survives a later move back to `MirrorPrune`. Applied to `vikunja-files`, `ntfy-data`,
   `garage-pvc`.
3. **`flux diff kustomization` needs `--path` (+ `--kustomization-file` when the CR lives
   elsewhere)**; bare invocation fails `invalid resource path ""`.
4. **Adoption bumps `metadata.generation` with no rollout** (vikunja 14→15). Generation is
   not evidence of a change; pod `uid` / RS hash are.
5. **SSA does not strip foreign annotations**: `argocd.argoproj.io/tracking-id` survived,
   `kubectl.kubernetes.io/last-applied-configuration` disappeared. So plan §3.1's tracking-id
   removal is cleanup, not a prerequisite. For in-sync plain manifests, **`ssa: IfNotPresent`
   was not needed at all** — `kustomize-controller | Apply` simply joined
   `argocd-controller | Update` in `managedFields`.
6. **Cluster-scoped resources + kustomize `namespace:` transformer is a silent trap.**
   `CiliumL2AnnouncementPolicy` got `namespace: garage` stamped; `kubectl diff` showed
   nothing and `apply --dry-run=server` *accepted* it — the API drops the field, leaving
   Flux's inventory holding a `garage/garage-l2` id for an object with no namespace. A
   `remove` patch cannot undo it: **patches run before the transformer** (`Unable to remove
   nonexistent key`). Hence garage carries explicit namespaces and no transformer.
7. **Flux self-heals on every interval**, not only on a new revision: a hand-patched
   `data.probe` was restored by the next `flux reconcile`.
8. **`flux diff` is blind to SOPS-encrypted values.** Control (plaintext ConfigMap edit) →
   drift reported, exit 1. Changed encrypted value → **exit 0, silent**, with or without
   `SOPS_AGE_KEY_FILE`. The CLI deliberately masks sops data (`internal/build.applySopsDiff`,
   `diffSopsSecret`, `maskSopsData`). Verify those with
   `sops -d <file> | kubectl apply --dry-run=server -f -`.
9. **Argo's root recreates deleted Applications.** `root-bootstrap` was
   `automated: {enabled: true, selfHeal: true}`; orphaning without freezing it would have
   resurrected all four from `apps/` and restored a second writer. Now frozen in Git.
10. **Argo reads `main`; a feature branch cannot freeze it.** The Application-file deletions
    are inert for Argo until merged — hence the merge + sync-ref flip in §5.

## 4. SOPS+age: verified mechanics

Working pipeline: `age-keygen` → `.sops.yaml` (`encrypted_regex: ^(data|stringData)$`) →
`sops --encrypt --in-place` → `spec.decryption.{provider: sops, secretRef: sops-age}`.

- The decryption Secret must be in the **namespace of the Kustomization object**, not the
  target (`internal/decryptor/decryptor.go` uses `kustomization.GetNamespace()`). Every
  Kustomization here lives in `flux-system`, so one Secret covers the fleet.
- The data key name must **end in `.agekey`** (`DecryptionAgeExt`); `--from-literal=key=…` is
  silently wrong.
- `spec.decryption` is still required per Kustomization even with the controller's
  `--sops-age-secret` fallback (present in the 2.9.6 binary), because `ImportKeys` returns
  early when it is nil.
- `.sops.yaml` is CLI-side only — the `GitRepository` ignore keeps it out of the artifact;
  the controller reads recipients from each file's `sops:` block.
- Live Secret comes back clean (`apiVersion,data,kind,metadata,type`) — the `sops:` block is
  stripped, so no strict-decoding rejection.
- Missing key presents as `Ready=False  BuildFailed: secrets "sops-age" not found`, and
  **nothing is destroyed** (decryption fails before apply). `flux reconcile` burns its whole
  `--timeout` instead of failing fast.

## 5. Open items, in order

1. ~~Push `main` and flip `ref.branch`.~~ Done — `origin/main` at `46ccd81`, live
   `spec.ref.branch: main`, procedure and trap in §5.1. The exit condition is met, so the last
   piece is deleting the branch: `git push origin --delete flux-migration`.
2. Root `automated` is no longer urgent. Once `main` dropped the four Application files, Argo's
   own refresh made `root-bootstrap` `Synced/Healthy` with `automated.enabled: false` — no manual
   root sync was needed. Keeping it frozen (plan phase 2, until the last app moves) now costs
   only that Renovate PRs touching `apps/arc.yaml` / `apps/renovate.yaml` need a manual root
   sync after merge.
3. ~~Commit the plan and this log.~~ Done (`660b5b9`); both had survived a migration branch and
   two incidents while untracked.
4. **Retiring ESO** — the undecided half of the §2.9 decision. SOPS+age itself is settled and
   proven; the 21 existing ExternalSecrets are untouched and none of them has to convert. Two
   blocking facts: `creationPolicy: Owner` puts
   an `ownerReference` on each Secret, so deleting an ExternalSecret garbage-collects it —
   cutover must be strip-ownerRef → Flux adopts → delete ES. And the same Bitwarden item feeds
   two Secrets for DB creds (`cnpg-system/vikunja` role + `vikunja/vikunja` app, both
   `1d29191d-f9b9-…`; same pattern for nextcloud, oxicloud, arroyo, risingwave, lakekeeper,
   openwebui), so those must move as a set with `infra/postgres`, not per app. Converting
   cannot read Bitwarden; values are only reachable from live Secrets.
5. 14 homelab apps left as Helm releases. `descheduler` is adopted and verified (§5.3), which
   makes the default path one `apply` per release rather than ~300 annotations — but only for
   releases whose live state equals the chart render. OxiCloud additionally needs
   `GitRepository` + `HelmChart` (chart at `charts/oxicloud` in upstream git, tag-pinned).
6. **Finish the `descheduler` cutover**: push the commit, apply `clusters/homelab/infra/
descheduler.yaml` (the sync CR is deliberately not live yet — only the HelmRelease and
   HelmRepository are), then `kubectl -n argocd delete application descheduler-affinity-sync
   --cascade=orphan`, then `chore(descheduler): drop argocd application`. Until the Application is
   gone, Argo keeps self-healing an object Flux now owns.
7. Cross-repo apps (myai, crypto-lakehouse) need commits in those repos, which were never
   touched.
8. Optional: `.gitignore` guard for `keys.txt` / `*.agekey` (repo currently ignores only
   `docs/public`).

### 5.1 Ref flip: `flux-migration` → `main`

`kubectl patch` alone cannot move the bootstrap ref, because the object being patched is itself
managed by the sync it configures: `kustomize-controller` re-applied `gotk-sync.yaml` from the
artifact it already held (`flux-migration@599a09ea`) and rewrote `spec.ref.branch` back. Two
reverts in a row, both visible as `managedFields: kustomize-controller | Apply` a second after
the patch, both with `Ready=True` throughout.

What worked, and why each step is load-bearing:

```bash
kubectl -n flux-system patch kustomization flux-system --type=merge -p '{"spec":{"suspend":true}}'
kubectl -n flux-system patch gitrepository flux-system --type=merge -p '{"spec":{"ref":{"branch":"main"}}}'
# wait for: status.artifact.revision == main@sha1:<sha>
kubectl -n flux-system patch kustomization flux-system --type=merge -p '{"spec":{"suspend":false}}'
```

* Suspend **only** `flux-system`. The four app Kustomizations have their own `spec.suspend`, so
  they kept reconciling the whole time.
* Merge-patch, not `kubectl apply`: the controllers own these objects by SSA, and re-applying
  the file invites field-ownership fights for a one-word change.
* Waiting for the `main` artifact before resuming is what makes it deterministic. Resuming
  while the controller still holds the old artifact just re-runs the revert — which is what
  happened on the first attempt.
* The Git must carry the change either way. A live-only patch is drift the next reconcile
  erases; the commit is the fix, the patch only closes the gap.

Residual trap: this converges only because the content of the branch being resumed
(`main`, `46ccd81`) says `branch: main`. If the branch still under read (`origin/flux-migration`
at the time) says `flux-migration`, a single stale apply pins it back **silently** — the
Kustomization stays `Ready`, and only the revision string reveals it. Pushing the one-liner to
both branches removes the race entirely; that is mechanically what `flux bootstrap` does.

### 5.2 First Helm release staged: `descheduler` — pre-flight only, nothing applied

In the tree, uncommitted: `infrastructure/controllers/descheduler/{kustomization,repository,
helmrelease}.yaml`, `clusters/homelab/infra/descheduler.yaml`, listed by
`clusters/homelab/kustomization.yaml`. Plus `scripts/helm-adopt.sh` (§3.1 enumerator, review by
default, `-a` to apply).

Identity, read off the live Application rather than inferred: `descheduler-affinity-sync` is an
**inline-values** Helm app — `repoURL: https://kubernetes-sigs.github.io/descheduler/`,
`chart: descheduler`, `targetRevision: 0.36.0`, values in `apps/descheduler.yaml`, **no `base/`
directory** — destination `kube-system`, and `automated: {prune: true, selfHeal: true}`, so Argo
is an active writer today. Hence `metadata.name: descheduler` with
`releaseName: descheduler-affinity-sync` pinned (§3.2), and no `targetNamespace` anywhere.

| Pre-flight | Result |
|---|---|
| `helm template` at Argo's release name/namespace | exactly the 5 live objects: `ServiceAccount`, `ConfigMap`, `ClusterRole`, `ClusterRoleBinding`, `CronJob` |
| inline values vs `apps/descheduler.yaml` | byte-identical after dedent (`diff` clean) |
| `kubectl diff -f <chart render>` vs live | **no spec differences** — only `argocd.argoproj.io/tracking-id` would drop, so adoption is a no-op for the workload |
| `kubectl apply --server-side --dry-run=server --field-manager=kustomize-controller` | accepted, **no conflicts**, no `--force-conflicts` needed. Argo used CSA here (`argocd-controller\|Update` + `last-applied-configuration`); CSA→SSA handover is clean, unlike the two-SSA-managers case plan §3.3 warns about |
| `kubectl apply --server-side --dry-run=server` on the two Flux CRs | accepted, after deleting `spec.retryInterval` (not a `HelmRelease` field — plan §2.7 was wrong, see plan §2.7 note) |
| `kubectl kustomize clusters/homelab` | renders (7 objects), so the new `infra/` path does not break the bootstrap root |

Two shape decisions worth repeating: no `namespace.yaml` (Flux must not be able to prune
`kube-system`), and no `wait`/`healthChecks` (a CronJob has no running workload to gate on and
Flux has no health check for the kind) — so the sync CR carries only `interval`, `prune: true`
and `deletionPolicy: Orphan`.

The annotation route turned out not to be needed — §5.3.

### 5.3 First Helm release adopted by take-ownership, not by annotations

Applied the two Flux CRs with `--server-side --force-conflicts` and **no** pre-stamped objects, to
see whether helm-controller v1.6.5 (Helm 4, `install.disableTakeOwnership` defaulting to `false`)
would adopt the release itself. Events: `HelmChartCreated` → `ChartPullSucceeded` →
`InstallSucceeded … release kube-system/descheduler-affinity-sync.v1 with chart descheduler@0.36.0`;
HelmRelease `Ready=True`.

| Check | Before | After |
|---|---|---|
| CronJob `uid` / `generation` | `9152b18e…` / 8 | `9152b18e…` / 8 — unchanged |
| ServiceAccount `uid` | `80e58428…` | unchanged |
| ConfigMap `uid` | `dda127cf…` | unchanged |
| `meta.helm.sh/release-name` + `-namespace`, `managed-by=Helm` | absent on all 5 | present on all 5, cluster-scoped included, **written by Helm** |
| Release storage | none | `sh.helm.release.v1.descheduler-affinity-sync.v1`; `helm history` → revision 1 `deployed` |
| Workload | CronJob completing every 15 min | still completing; Argo still reports `Synced/Healthy` |

No `--force-conflicts` on the chart objects was needed and none is available — the CRD exposes
`install.serverSideApply` but no `forceConflicts` field — so the helm/helm#31510 caveat about
take-ownership needing forced conflicts did not apply to CSA-owned objects.

`install.strategy: RetryOnFailure` was already set, which is the guard that matters here:
helm/helm#31333 means a failed install that is then uninstalled can destroy the objects it failed
to take over, so a red HelmRelease gets repaired in place rather than deleted. Recorded in plan
§3.1 as mandatory on both the default and the annotation path.

What this changes: §3.1's ~300 annotations become one `apply` per release, *provided* the chart
render has no spec differences against live. It does not remove the risk, it concentrates it — the
six drifted releases (`nextcloud`, `nats`, `monitoring`, `openwebui`, `oxicloud`, `cert-manager`)
will have the chart's state written over theirs, and CNPG/Longhorn CRs are mutated by their
operators, so those keep the scripted fallback route plus `ssa: IfNotPresent`/`Merge`.

State left mid-cutover on purpose: `HelmRelease` and `HelmRepository` are live, the
`clusters/homelab/infra/descheduler.yaml` sync CR is not applied yet (it arrives with the push),
and the Argo Application is still present — see §5 item 6.

## 6. Cluster noise observed, unrelated to the migration

`pg-cluster` was not Ready on Oct 29 (readyInstances 1/3, `pg-cluster-1` stuck in `Init` with
Longhorn `MountDevice … exit status 32`, `pg-cluster-2` dangling); vikunja crashlooped on
`no route to host` to `pg-cluster-rw`. On Oct 30 a batch of `elcungem` pods rescheduled
together (`pg-cluster-2`, `garage`, an ARC runner, vikunja) with no node reboot.
`externalsecret/vikunja` hit `context deadline exceeded` against
`bitwarden-sdk-server.external-secrets`. None of these correlate with adoption — RS hashes
and generations were unchanged throughout.

**Recurrence 2026-11-01 13:49–13:51Z.** kubelets on `elcungem`, `elcunal` and `opizero3` all
re-registered inside two minutes (`elcunhp1` had gone `NodeStatusUnknown` at 11:38Z), pods
rescheduled onto `elcungem`, and `cilium-cni` saturated: `putEndpointIdTooManyRequests` and
`Cilium API client timeout exceeded` on pod sandboxes cluster-wide, with Longhorn following up
`AttachVolume.Attach … DeadlineExceeded` for `pg-cluster-3` and `loki-0`. Flux's own
`kustomize-controller` and `helm-controller` landed on `elcungem` and sat at `0/1` — which is
the only reason `flux-system` still reported the pre-flip revision afterwards. Same signature as
Oct 30, so it is worth a node-side look (`cilium-agent` restarts, kubelet/journald around
13:49Z) rather than treating it as one-off noise.

Recovered by ~15:00Z: `elcunhp1` Ready, all four `cilium-agent`s Running, `pg-cluster` 3/3
healthy with `pg-cluster-3` primary, vikunja/ntfy/garage back on their original ReplicaSets
(`6586d74bbb`, `5596ff8dd6`, `64c5c9777f`), `garage-pvc` still Bound, `vikunja-sops-probe` intact
and still `kustomize-controller | Apply`-owned. Cost of the window: no `kustomize-controller` or
`helm-controller` reconcile between ~11:42Z and ~14:00Z, so Flux was inert for about two hours.
Worth weighing against plan §8 — Argo would not have helped either: both engines are workloads on
the cluster they manage, and Flux's controllers are one replica each.
