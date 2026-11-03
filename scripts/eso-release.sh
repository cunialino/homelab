#!/usr/bin/env bash
# Release one Secret from External Secrets Operator without losing it.
#
# Two orders of operations exist and only one is safe. If the ExternalSecret is inside a Flux
# inventory, deleting it from Git makes kustomize-controller prune it, and the ownerReference that
# creationPolicy: Owner put on the Secret makes the API garbage-collect the Secret with it. So for
# those: release on the cluster first, then change Git (prune becomes a no-op, nothing to collect).
#
#   scripts/eso-release.sh <namespace> <secret-name>
set -uo pipefail
ns=${1:?namespace}; name=${2:?secret name}

uid0=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.uid}')
sha0=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.data}' | sha256sum | cut -c1-8)
echo "before: uid=$uid0 data-sha=$sha0"
echo "        ownerRefs=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}')"

replicas0=$(timeout 60 kubectl -n external-secrets get deploy external-secrets -o jsonpath='{.spec.replicas}')
timeout 90 kubectl -n external-secrets scale deploy external-secrets --replicas=0 >/dev/null
sleep 3
timeout 60 kubectl -n $ns patch secret $name --type=merge -p '{"metadata":{"ownerReferences":null}}' >/dev/null && echo "ownerReference stripped"
timeout 60 kubectl -n $ns delete externalsecret $name --wait=false 2>&1 | tail -1
sleep 5
if timeout 30 kubectl -n $ns get externalsecret $name >/dev/null 2>&1; then
  fin=$(timeout 30 kubectl -n $ns get externalsecret $name -o jsonpath='{.metadata.finalizers}')
  if [ -n "$fin" ]; then
    echo "releasing finalizer $fin (deletionPolicy Retain leaves it nothing to clean)"
    timeout 60 kubectl -n $ns patch externalsecret $name --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null
  fi
fi
timeout 90 kubectl -n external-secrets scale deploy external-secrets --replicas="${replicas0:-1}" >/dev/null
timeout 60 kubectl -n $ns patch secret $name --type=merge -p \
  '{"metadata":{"labels":{"reconcile.external-secrets.io/managed":null,"reconcile.external-secrets.io/created-by":null}}}' >/dev/null
echo "ESO labels stripped; controller restored to ${replicas0:-1}"

sleep 15
uid1=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.uid}')
sha1=$(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.data}' | sha256sum | cut -c1-8)
echo "after:  uid=$uid1"
echo "  uid unchanged : $([ "$uid0" = "$uid1" ] && echo YES || echo "NO ($uid0 -> $uid1)")"
echo "  data unchanged: $([ "$sha0" = "$sha1" ] && echo "YES ($sha1)" || echo "NO ($sha0 -> $sha1)")"
echo "  ownerRefs     : $(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.ownerReferences}' | sed 's/^$/none/')"
echo "  labels        : $(timeout 60 kubectl -n $ns get secret $name -o jsonpath='{.metadata.labels}')"
echo "  ES gone       : $(timeout 30 kubectl -n $ns get externalsecret $name >/dev/null 2>&1 && echo 'NO' || echo yes)"
echo "  ES left       : $(timeout 60 kubectl get externalsecret -A --no-headers | wc -l)"
echo "  ESO           : $(timeout 60 kubectl -n external-secrets get deploy external-secrets --no-headers | awk '{print $2}')"
