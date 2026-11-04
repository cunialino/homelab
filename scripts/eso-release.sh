#!/usr/bin/env bash
# Move one Secret from External Secrets Operator to a Git-managed SOPS manifest.
#
# The order matters twice over, and both failure modes delete the Secret:
#
#   1. Git first, cluster second. If the ExternalSecret sits inside a Flux inventory, dropping its
#      manifest makes kustomize-controller prune it. creationPolicy: Owner put an ownerReference on
#      the Secret, so the API garbage-collects the Secret along with it.
#
#   2. Cluster first, Git second. Deleting the ExternalSecret while Git still declares it lets any
#      sync of the old revision recreate it, and ESO adopts the existing Secret with a fresh
#      ownerReference. The prune in step 1 then takes the Secret with it. This is how
#      cnpg-system/lakekeeper-secret was lost on 2026-11-04 despite a clean-looking cutover.
#
# So ESO stays scaled to zero from before the push until the new revision is applied: a recreated
# ExternalSecret cannot adopt the Secret while its controller is down, and the prune is then inert.
#
#   scripts/eso-release.sh pause              <- run immediately before pushing the Git change
#   scripts/eso-release.sh after <ns> <name>  <- run once flux reports the new revision
set -uo pipefail
mode=${1:?pause|after}

if [ "$mode" = pause ]; then
  timeout 90 kubectl -n external-secrets scale deploy external-secrets --replicas=0 >/dev/null
  timeout 90 kubectl -n external-secrets wait deploy external-secrets --for=delete pod --timeout=90s 2>/dev/null
  echo "ESO paused. Push the commit that swaps the ExternalSecret for the SOPS Secret, then run:"
  echo "  scripts/eso-release.sh after <namespace> <secret-name>"
  exit 0
fi

ns=${2:?namespace}; name=${3:?secret name}
uid0=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.uid}')
sha0=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.data}' | sha256sum | cut -c1-8)
echo "before: uid=$uid0 data-sha=$sha0"

# Order matters here: the ownerReference has to be gone before the ExternalSecret is, otherwise the
# API server garbage-collects the Secret in the gap between the two calls.
timeout 60 kubectl -n $ns patch secret $name --type=merge -p '{"metadata":{"ownerReferences":null}}' >/dev/null
echo "ownerReference stripped"
if timeout 30 kubectl -n $ns get externalsecret $name >/dev/null 2>&1; then
  echo "ExternalSecret still present, removing it"
  timeout 60 kubectl -n $ns delete externalsecret $name --wait=false 2>&1 | tail -1
  sleep 3
  fin=$(timeout 30 kubectl -n $ns get externalsecret $name -o jsonpath='{.metadata.finalizers}' 2>/dev/null)
  [ -n "$fin" ] && timeout 60 kubectl -n $ns patch externalsecret $name --type=merge \
    -p '{"metadata":{"finalizers":null}}' >/dev/null && echo "released finalizer $fin"
fi
timeout 60 kubectl -n $ns patch secret $name --type=merge -p \
  '{"metadata":{"labels":{"reconcile.external-secrets.io/managed":null,"reconcile.external-secrets.io/created-by":null}}}' >/dev/null
timeout 90 kubectl -n external-secrets scale deploy external-secrets --replicas=1 >/dev/null
echo "ESO labels stripped; controller restored"

sleep 15
uid1=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.uid}')
sha1=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.data}' | sha256sum | cut -c1-8)
echo "after:  uid=$uid1 data-sha=$sha1"
[ "$uid0" = "$uid1" ] || echo "  WARNING uid changed: object was deleted and recreated; re-check the value"
[ "$sha0" = "$sha1" ] || echo "  WARNING data changed: $sha0 -> $sha1"
echo "  ownerRefs : $(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.ownerReferences[0].kind}' | sed 's/^$/none/')"
echo "  labels    : $(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.labels}')"
echo "  ES gone   : $(timeout 30 kubectl -n $ns get externalsecret $name >/dev/null 2>&1 && echo NO || echo yes)"
echo "  ES left   : $(timeout 60 kubectl get externalsecret -A --no-headers | wc -l)"
echo "  ESO       : $(timeout 60 kubectl -n external-secrets get deploy external-secrets --no-headers | awk '{print $2}')"
