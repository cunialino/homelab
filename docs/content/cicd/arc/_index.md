+++
title = "ARC Runners"
weight = 2
sort_by = "weight"

[extra]
+++

I deployed the [Action Runners Controller](https://github.com/actions/actions-runner-controller) to run GitHub Actions on my cluster. This enables me to execute CI/CD workflows directly on infrastructure I control, rather than relying solely on GitHub-hosted runners.

## Use Cases

ARC runners serve multiple purposes in my pipeline:
- **GitHub Pages deployment**: The site you're reading is deployed via GitHub Actions triggered by ARC runners
- **dbt docs serving**: Documentation generation and deployment for dbt projects
- **Docker image builds**: Container image construction and registry pushes

## Configuration

ARC Runners are configured in [infrastructure/controllers/arc-runners/](https://github.com/cunialino/homelab/tree/main/infrastructure/controllers/arc-runners/): one `HelmRelease` for the controller and one for the autoscaling runner scale set, values inline. I use `longhorn` as the storage class for runner work volumes, ensuring persistent storage for build processes. The credentials the controller authenticates to GitHub with are a [SOPS-encrypted Secret](/utils/secrets/) in [secret-auth.yaml](https://github.com/cunialino/homelab/blob/main/infrastructure/controllers/arc-runners/secret-auth.yaml).

The [crypto-lakehouse](https://github.com/cunialino/crypto-lakehouse) repository runs a second scale set for its own builds, declared in that repository and synced by [clusters/homelab/apps/arc-runners-crypto.yaml](https://github.com/cunialino/homelab/blob/main/clusters/homelab/apps/arc-runners-crypto.yaml). Both scale sets share this controller, so the repository keeps the namespace, the controller and the credentials.

## Container Build Workflow

For Docker image builds, I avoid the complexity of docker-in-docker (dind) setups or sidecar containers running container runtimes. Instead, I leverage [nix](https://nixos.org/) to build container image layers directly on the runner, then use [skopeo](https://github.com/containers/skopeo) to push the resulting tar file to my registry.

This approach provides several advantages:
- **No nested container runtime**: Eliminates the need for Docker daemon inside Kubernetes pods
- **Reproducible builds**: Nix ensures deterministic dependency resolution and build artifacts
- **Clean separation**: Build logic lives in nix expressions, while skopeo handles image transport
- **Reduced attack surface**: No privileged containers or host namespace access required

The workflow typically involves:
1. Nix evaluates dependencies and builds the image layers as a tar archive
2. Skopeo copies the tar file to the target registry with proper authentication
3. The resulting image is available for deployment via Flux
