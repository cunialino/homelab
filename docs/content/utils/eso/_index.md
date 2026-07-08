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

### TLS Certificate

The Bitwarden SDK server requires a TLS certificate for secure internal communication. I use a self-signed certificate provisioned via [cert-manager](https://cert-manager.io/) (deployed separately at [apps/cert-manager.yaml](https://github.com/cunialino/homelab/tree/main/apps/cert-manager.yaml)).

The `Certificate` resource ([base/eso/bitclustertls.yaml](https://github.com/cunialino/homelab/tree/main/base/eso/bitclustertls.yaml)) creates a CA certificate signed by cert-manager's self-signed `ClusterIssuer` ([base/cert-manager/cluster-issuer.yaml](https://github.com/cunialino/homelab/tree/main/base/cert-manager/cluster-issuer.yaml)). The resulting secret is mounted by the Bitwarden SDK server pod for TLS termination.

This keeps the entire certificate lifecycle — issuance, renewal, distribution — managed within Kubernetes without external dependencies.

### Kustomization

The `kustomization.yaml` file in [base/eso/](https://github.com/cunialino/homelab/tree/main/base/eso/) combines the network policy, cluster secret store, and TLS certificate configurations.

### Values

The `values.yaml` file ([base/eso/values.yaml](https://github.com/cunialino/homelab/tree/main/base/eso/values.yaml)) enables the installation of CRDs and activates the Bitwarden SDK server component of External Secrets.