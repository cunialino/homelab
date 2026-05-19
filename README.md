# Homelab

Homelab k3s infra.

My cluster is made of 4 nodes, configured with nixos (because why not).

The module I use is [this](https://github.com/cunialino/dotfiles/blob/main/sys_mods/k3s/default.nix)

On top of this, I opted for the [cilium](https://cilium.io/) cni, with [these values](./cilium.yaml).


## Bootstrapping the cluster

After running nixos-rebuild on all nodes and once all the nodes joined the cluster,
we need to apply the cilium config with `cilium install --kubeconfig <path_to_k3s_kubeconfig>`.

Then, we bootstrap [argocd](https://argo-cd.readthedocs.io/en/stable/):
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd -f base/argocd/values.yaml --create-namespace
```

After this, apply the [root-app.yaml](./bootstrap/root-app.yaml) to bootstrap everything:
```bash
kubectl apply -f bootstrap/root-app.yaml
```

ArgoCD manages itself via [apps/argocd.yaml](./apps/argocd.yaml). All further configuration is GitOps-driven.

**Note:** the argo cd part was not done this way on the just created cluster, i applied the raw manifests at first.
