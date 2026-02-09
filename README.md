# Homelab

Homelab k3s infra.

My cluster is made of 4 nodes, configured with nixos (because why not).

The module I use is [this](https://github.com/cunialino/dotfiles/blob/main/sys_mods/k3s/default.nix)

On top of this, I opted for the [cilium](https://cilium.io/) cni, with [these values](./cilium.yaml).


## Bootstrapping the cluster

After running nixos-rebuild on all nodes and once all the nodes joined the cluster,
we need to apply the cilium config with `cilium install --kubeconfig <path_to_k3s_kubeconfig>`.

Then, we bootstrap [argocd](https://argo-cd.readthedocs.io/en/stable/): 
`kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`

After this, I configured it via the webui (noob me, it was the first time using argocd), to connect to this repo via a PAT token.

Last step before full automation was to apply the [root-app.yaml](./bootstrap/root-app.yaml)
