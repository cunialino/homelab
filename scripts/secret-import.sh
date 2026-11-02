#!/usr/bin/env bash
# Turn a live Secret into an age-encrypted manifest for Git, so Flux (kustomize-controller)
# becomes its writer instead of an ExternalSecret. Used while retiring External Secrets; the
# receiving Kustomization needs spec.decryption.
#
#   scripts/secret-import.sh <namespace> <secret-name> <output.yaml>
#
# Read-only against the cluster. The plaintext file exists at <output.yaml> only between the
# dump and the sops in-place encryption; the script aborts and removes it if sops fails.
#
# Deleting the old ExternalSecret afterwards needs care: creationPolicy: Owner puts a
# controller ownerReference on the Secret, so the API garbage-collects it when the
# ExternalSecret goes, even with deletionPolicy: Retain. Strip the ownerReference first,
# let Flux apply the identical content, confirm the data, then delete the ExternalSecret.
set -euo pipefail

if [[ $# -ne 3 ]]; then sed -n '2,15p' "$0"; exit 2; fi
ns=$1; name=$2; out=$3

# Values are emitted through @json: labels must be strings, so a bare `cnpg.io/reload: true`
# is rejected by the API as a bool, and annotations regularly contain colons.
keep_labels=$(kubectl -n "$ns" get secret "$name" -o json \
  | jq -r '[(.metadata.labels // {}) | to_entries[]
            | select(.key | startswith("reconcile.external-secrets.io")
                             or startswith("kustomize.toolkit.fluxcd.io")
                             or startswith("argocd.argoproj.io") | not)]
           | map("\(.key): \(.value | @json)") | join("\n")')

keep_annotations=$(kubectl -n "$ns" get secret "$name" -o json \
  | jq -r '[(.metadata.annotations // {}) | to_entries[]
            | select(.key | startswith("reconcile.external-secrets.io")
                             or startswith("kubectl.kubernetes.io")
                             or startswith("argocd.argoproj.io") | not)]
           | map("\(.key): \(.value | @json)") | join("\n")')

secret_type=$(kubectl -n "$ns" get secret "$name" -o jsonpath='{.type}')
data=$(kubectl -n "$ns" get secret "$name" -o json \
  | jq -r '(.data // {}) | to_entries[] | "  \(.key): \(.value)"')

{
  echo "apiVersion: v1"
  echo "kind: Secret"
  echo "metadata:"
  echo "  name: $name"
  echo "  namespace: $ns"
  if [[ -n "$keep_labels" ]]; then
    echo "  labels:"; echo "$keep_labels" | sed 's/^/    /'
  fi
  if [[ -n "$keep_annotations" ]]; then
    echo "  annotations:"; echo "$keep_annotations" | sed 's/^/    /'
  fi
  echo "type: $secret_type"
  echo "data:"
  echo "$data"
} > "$out"

# sops picks its creation rule from the file path, so encrypt the real path, not a temp file.
if ! nix run nixpkgs#sops -- --encrypt --in-place "$out"; then
  rm -f "$out"
  echo "sops failed; $out removed rather than left in plaintext" >&2
  exit 1
fi

# Confirm the file decrypts to the same values the cluster holds before trusting it.
decrypted=$(nix run nixpkgs#sops -- --decrypt "$out")
for key in $(kubectl -n "$ns" get secret "$name" -o json | jq -r '.data | keys[]'); do
  live=$(kubectl -n "$ns" get secret "$name" -o json | jq -r --arg k "$key" '.data[$k]')
  # sops re-indents to 4 spaces, so match on leading whitespace rather than the repo style.
  got=$(printf '%s\n' "$decrypted" | sed -n "s/^[[:space:]]*$key: //p")
  [[ -n "$got" && "$live" == "$got" ]] || { echo "round-trip mismatch for key $key" >&2; exit 1; }
done

echo "encrypted $ns/$name -> $out ($(grep -c '' "$out") lines)"
