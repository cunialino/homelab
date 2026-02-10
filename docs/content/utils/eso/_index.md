+++
title = "External Secrets Operator"
weight = 2
sort_by = "weight"

[extra]
+++

The [External Secrets Operator (ESO)](https://external-secrets.io/) allows me to use external secret management systems, like Bitwarden, to securely inject secrets into my Kubernetes cluster.

## Configuration

I deploy ESO via ArgoCD, with its main configuration in [apps/eso.yaml](https://github.com/cunialino/homelab/tree/main/apps/eso.yaml) and specific configurations in [base/eso/](https://github.com/cunialino/homelab/tree/main/base/eso/).

### Cluster Secret Store

The `ClusterSecretStore` ([base/eso/clustersecretstore.yaml](https://github.com/cunialino/homelab/tree/main/base/eso/clustersecretstore.yaml)) named `bitwarden-secretsmanager` is configured to connect to a self-hosted Bitwarden Secrets Manager instance. It specifies the Bitwarden server SDK URL, identity URL, API URL, organization ID, project ID, and references a Kubernetes Secret for authentication credentials.

### Network Policy

I apply a `CiliumNetworkPolicy` ([base/eso/network_policy.yaml](https://github.com/cunialino/homelab/tree/main/base/eso/network_policy.yaml)) named `bitwarden-sdk-security` to restrict access to the Bitwarden SDK server within the `external-secrets` namespace. This policy ensures that only the External Secrets Operator and specific CIDR ranges can communicate with the SDK server on port 9998.

### Kustomization

The `kustomization.yaml` file in [base/eso/](https://github.com/cunialino/homelab/tree/main/base/eso/) combines my network policy and the cluster secret store configurations.

### Values

The `values.yaml` file ([base/eso/values.yaml](https://github.com/cunialino/homelab/tree/main/base/eso/values.yaml)) enables the installation of CRDs and activates the Bitwarden SDK server component of External Secrets.