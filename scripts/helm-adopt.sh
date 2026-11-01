#!/usr/bin/env bash
# Adopt objects that ArgoCD applied into Helm ownership, so helm-controller can take over a
# release without deleting and recreating it (migration plan §3.1). Argo renders Helm templates
# and applies them as plain manifests, so live objects have no meta.helm.sh/* annotations and
# helm-controller refuses them with "invalid ownership metadata".
#
#   scripts/helm-adopt.sh <release> <namespace> <rendered.yaml>        # review only
#   scripts/helm-adopt.sh -a <release> <namespace> <rendered.yaml>     # apply
#
# Render the manifest with the release name and namespace Argo actually used, e.g.
#   helm template descheduler-affinity-sync descheduler \
#     --repo https://kubernetes-sigs.github.io/descheduler/ --version 0.36.0 \
#     -n kube-system -f values.yaml > /tmp/rendered.yaml
#
# Review the printed list before using -a. Nothing here is idempotent-sensitive: re-running just
# re-annotates. Removing the metadata again is the rollback (plan §7).
set -euo pipefail

apply=0
if [[ "${1:-}" == "-a" ]]; then apply=1; shift; fi
if [[ $# -ne 3 ]]; then sed -n '2,12p' "$0"; exit 2; fi

release=$1; ns=$2; rendered=$3

# "|" and not a tab: TAB is IFS whitespace, so `read` collapses the empty field of a
# cluster-scoped object and shifts the name into the namespace column.
objects=$(kubectl apply --dry-run=client --validate=false -o json -f "$rendered" |
  jq -r '.items[] | select(.kind != null and .metadata.name != null)
         | [.kind, (.metadata.namespace // ""), .metadata.name] | join("|")')

if [[ -z "$objects" ]]; then
  echo "no objects parsed from $rendered" >&2
  exit 1
fi

printf '%-22s %-14s %-34s %-12s %s\n' KIND NAMESPACE NAME HELM_ANN OWNERS
commands=()

while IFS='|' read -r kind objns name; do
  [[ -z "$kind" || -z "$name" ]] && continue
  scope=(-n "${objns:-$ns}")
  [[ -z "$objns" ]] && scope=()

  live=$(kubectl get "$kind" "$name" "${scope[@]}" --show-managed-fields -o json 2>/dev/null) || {
    printf '%-22s %-14s %-34s %-12s %s\n' "$kind" "${objns:--}" "$name" "-" "absent: helm creates it"
    continue
  }

  helm_ann=$(jq -r '[(.metadata.annotations // {}) | to_entries[]
                     | select(.key | startswith("meta.helm.sh")) | .key] | join(",")' <<<"$live")
  owners=$(jq -r '(.metadata.managedFields // []) | map(.manager + "|" + .operation) | unique | join(" ")' <<<"$live")
  printf '%-22s %-14s %-34s %-12s %s\n' "$kind" "${objns:--}" "$name" "${helm_ann:-MISSING}" "$owners"

  target="${scope[*]:+${scope[*]}}"
  commands+=("kubectl ${target:+$target }annotate $kind $name meta.helm.sh/release-name=$release meta.helm.sh/release-namespace=${objns:-$ns} --overwrite")
  commands+=("kubectl ${target:+$target }label $kind $name app.kubernetes.io/managed-by=Helm --overwrite")
done <<< "$objects"

echo
if [[ $apply -eq 1 ]]; then
  printf '%s\n' "${commands[@]}" | xargs -L1 sh -c
else
  printf '%s\n' "${commands[@]}"
fi
