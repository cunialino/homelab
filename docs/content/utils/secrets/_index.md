+++
title = "Secrets"
weight = 2
sort_by = "weight"

[extra]
+++

Secrets live in Git as ordinary Kubernetes `Secret` manifests, encrypted with [SOPS](https://github.com/getsops/sops) against an [age](https://github.com/FiloSottile/age) key. Flux decrypts them at apply time, so nothing in the cluster knows they started life in a repository.

## What gets encrypted

`.sops.yaml` at the repository root decides it, and `encrypted_regex` narrows the work to the payload only:

```yaml
creation_rules:
  - path_regex: \.ya?ml$
    encrypted_regex: ^(data|stringData)$
    age: "age1..."
```

Everything outside `data` and `stringData` stays in clear text — the name, the namespace, the labels — so a diff still says which application changed and a reviewer never has to decrypt a manifest to understand it.

The same age key is shared by all three repositories that deploy here, so one secret in `flux-system` unlocks the whole cluster:

```yaml
decryption:
  provider: sops
  secretRef:
    name: sops-age
```

Any Flux `Kustomization` that ships an encrypted Secret carries that block. Without it Flux applies the ciphertext as-is and the application fails on a value that looks like `ENC[AES256_GCM,...]`.

## Two halves of one password

A `Secret` can only be read from its own namespace, and the CloudNativePG operator has no rights to write outside `cnpg-system`. So every database credential exists twice: the role credential the operator consumes in `cnpg-system`, and a copy in the application's namespace that it reads through `secretKeyRef`.

The two live in different layers — [infrastructure/configs/postgres/](https://github.com/cunialino/homelab/tree/main/infrastructure/configs/postgres/) and the application's own directory — which means rotating a password is an edit in two files, done together. Rotating one half alone leaves the cluster with a working application and a role credential that no longer matches, or the other way round.

## Editing an encrypted file

With `sops` and the key available:

```
sops edit clusters/homelab/apps/vikunja/secret-app.yaml
```

Push it and Flux applies the plaintext; the cluster never stores the key, only the value.
