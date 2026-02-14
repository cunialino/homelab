+++
title = "Security Practices"
description = "Security model and best practices for the homelab cluster"
weight = 3

[extra]
+++

## Security Model

This homelab implements a defense-in-depth security strategy with multiple layers of protection.

### Network Security (Cilium)

Cilium provides the core network security layer using eBPF technology:

#### Network Policies

Network policies are defined using CiliumNetworkPolicy resources. You can see an example implementation in [base/eso/network_policy.yaml](https://github.com/cunialino/homelab/tree/main/base/eso/network_policy.yaml).

A typical CiliumNetworkPolicy specifies:
- **endpointSelector**: Selects which pods the policy applies to using labels
- **ingress rules**: Defines allowed incoming traffic sources and ports
- **egress rules**: Defines allowed outgoing traffic destinations and ports
- **Layer 7 rules**: HTTP/gRPC filtering for application-level security

#### Key Security Features

- **Identity-based security**: Security policies based on workload identity, not IP addresses
- **Zero-trust networking**: Deny-all default policy with explicit allow rules
- **Layer 7 filtering**: HTTP, gRPC, and Kafka protocol-aware filtering
- **DNS-based policies**: Allow traffic only to specific DNS names
- **Encrypted communication**: WireGuard encryption for pod-to-pod traffic (optional)

### Secret Management

#### Personal Access Token (PAT) Management

**Best Practices:**

1. **Store in external secret managers**: Use Bitwarden Secrets Manager (via ESO) instead of Kubernetes Secrets
2. **Rotate regularly**: Set expiration dates on PATs and rotate them periodically
3. **Principle of least privilege**: Grant only necessary permissions to each PAT
4. **Audit access**: Monitor PAT usage in GitHub/GitLab
5. **Never commit secrets**: Use External Secrets Operator to inject secrets at runtime

**Example Implementation:**

External secrets are configured using ExternalSecret resources that reference external secret managers. An example can be found in the ARC (Action Runners Controller) configuration at [base/arc/secret_pat.yaml](https://github.com/cunialino/homelab/tree/main/base/arc/secret_pat.yaml).

The ExternalSecret resource specifies:
- **refreshInterval**: How often to sync secrets from the external provider
- **secretStoreRef**: References the ClusterSecretStore (e.g., Bitwarden)
- **target**: Defines the Kubernetes Secret to create
- **data**: Maps external secret keys to Kubernetes secret keys

### Infrastructure Security

#### NixOS Security Features

- **Immutable system configuration**: All system changes go through version-controlled Nix expressions
- **Reproducible builds**: Identical system configurations across all nodes
- **Minimal attack surface**: Only necessary services are installed and running
- **Atomic upgrades**: Rollback capability if updates cause issues

#### Cluster Security

- **RBAC**: Kubernetes Role-Based Access Control for fine-grained permissions
- **Network policies**: Cilium policies restrict inter-pod communication
- **Pod security standards**: Enforced security contexts for all workloads
- **Read-only root filesystems**: Where possible, containers run with read-only filesystems

### GitOps Security

#### Repository Security

- **Protected branches**: Main branch requires pull request reviews
- **Signed commits**: Git commit signing for verification
- **No secrets in Git**: All sensitive data stored in Bitwarden
- **Dependency scanning**: Automated vulnerability scanning of container images

#### ArgoCD Security Model

- **Resource pruning disabled**: Prevents accidental deletion (`prune: false`)
- **Self-healing enabled**: Automatically corrects configuration drift
- **Git as source of truth**: All changes tracked and auditable
- **Application projects**: Isolate different environments (dev/staging/prod)

### Monitoring and Observability

#### Security Monitoring

- **Hubble**: Real-time network flow visibility and security event detection
- **Prometheus alerts**: Anomaly detection for unusual traffic patterns
- **Audit logging**: Kubernetes audit logs for API server access
- **Log aggregation**: Centralized logging for security event analysis

#### Network Observability

```bash
# View network flows with Hubble
hubble observe --namespace production

# Check dropped packets
hubble observe --verdict DROPPED

# Monitor specific endpoints
hubble observe --to-pod backend-app
```

### Operational Security

#### Access Control

- **SSH key-based authentication**: No password-based SSH access
- **Firewall rules**: UFW/iptables restrict external access
- **VPN access**: Management access requires VPN connection
- **Multi-factor authentication**: Where applicable (GitHub, Bitwarden)

#### Backup and Recovery

- **Encrypted backups**: All backups encrypted at rest
- **Offline copies**: Critical backups stored offline
- **Regular testing**: Periodic restoration testing
- **Version control**: All infrastructure as code in Git

### Security Checklist

When adding new applications:

- [ ] Does it require a CiliumNetworkPolicy?
- [ ] Are secrets stored in Bitwarden (not in Git)?
- [ ] Is the container running as non-root?
- [ ] Are resource limits defined?
- [ ] Is the image from a trusted registry?
- [ ] Are security contexts properly configured?
- [ ] Is ingress/egress traffic minimized?
- [ ] Are logs being collected?
- [ ] Are alerts configured for anomalies?

### Incident Response

In case of security incidents:

1. **Isolate**: Use Cilium policies to isolate affected workloads
2. **Investigate**: Use Hubble and logs to understand the scope
3. **Remediate**: Update configurations and redeploy via GitOps
4. **Document**: Record lessons learned in runbooks
5. **Improve**: Update security policies based on findings
