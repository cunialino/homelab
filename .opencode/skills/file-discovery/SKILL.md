---
name: file-discovery
description: Maps the homelab repo to find Zola docs, ArgoCD apps, and K8s manifests.
---
## Search Protocol
1. **Zola Sections:** Search `docs/content/**/_index.md` to understand the site structure.
2. **ArgoCD Apps:** Search `apps/` for ArgoCD Application manifests (usually YAML).
3. **K8s Manifests:** Search `base/**` for the core resource definitions (Deployments, Services).

## Link Generation Rule
Whenever you reference a file in your response or documentation:
1. Identify the file path relative to the repo root (e.g., `apps/pihole.yaml`).
2. Construct a GitHub link: `https://github.com/cunialino/homelab/tree/main/<path>`.
3. Example: [pihole.yaml](https://github.com/cunialino/homelab/tree/main/apps/pihole.yaml)
