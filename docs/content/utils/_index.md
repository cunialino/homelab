+++
title = "Utilities"
description = "Supporting tools and operators that enhance cluster functionality"
weight = 6
sort_by = "weight"

[extra]
+++

This section documents utility tools and operators that support the core infrastructure. These components handle cross-cutting concerns like secret management, resource optimization, and operational automation.

## Overview

Utilities provide essential services that don't fit into core categories:

- **[External Secrets Operator](/utils/eso)** - Secure secret management with Bitwarden
- **[Descheduler](/utils/descheduler)** - Intelligent pod rescheduling for resource optimization

## Why These Utilities?

### Secret Management

Managing secrets securely is critical. [External Secrets Operator](/utils/eso) integrates with external secret providers (Bitwarden) to:
- Avoid storing secrets in Git
- Centralize secret management
- Automate secret rotation
- Enable audit trails

### Resource Optimization

The [Descheduler](/utils/descheduler) improves cluster efficiency by:
- Rebalancing pods across nodes
- Evicting pods from overutilized nodes
- Consolidating workloads to free up nodes
- Improving resource utilization

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Utility Layer                            │
│                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │  External Secrets   │    │    Descheduler      │        │
│  │     Operator        │    │                     │        │
│  │                     │    │                     │        │
│  │  ┌───────────────┐  │    │  ┌───────────────┐  │        │
│  │  │  Bitwarden    │  │    │  │   Policies    │  │        │
│  │  │   Secrets     │◄─┼────┼──┼──► Node       │  │        │
│  │  │   Manager     │  │    │  │   Balancing   │  │        │
│  │  └───────┬───────┘  │    │  └───────┬───────┘  │        │
│  │          │          │    │          │          │        │
│  │  ┌───────▼───────┐  │    │  ┌───────▼───────┐  │        │
│  │  │ K8s Secrets   │  │    │  │ Pod Eviction  │  │        │
│  │  └───────────────┘  │    │  └───────────────┘  │        │
│  └─────────────────────┘    └─────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Integration with Core Components

These utilities integrate with other homelab components:

| Utility | Integrates With | Purpose |
|---------|----------------|---------|
| ESO | [CI/CD](/cicd) | Provides GitHub PAT for ARC runners |
| ESO | [CNPG](/cnpg) | Database credentials management |
| Descheduler | All Workloads | Optimizes pod placement |
| ESO | [Monitoring](/monitoring) | Alertmanager credentials |

## Best Practices

### Secret Management

1. **Never commit secrets**: All secrets stored in Bitwarden
2. **Use ClusterSecretStore**: Share secrets across namespaces when appropriate
3. **Rotate regularly**: Set short refresh intervals for critical secrets
4. **Audit access**: Review ExternalSecret resources periodically

### Resource Optimization

1. **Monitor descheduler logs**: Check for evictions and imbalances
2. **Tune policies**: Adjust thresholds based on workload patterns
3. **Combine with HPA**: Use Horizontal Pod Autoscaler for dynamic scaling
4. **Node affinity**: Set appropriate node selectors for critical workloads

## Related Documentation

- **[Getting Started](/getting-started)** - Quick overview of all components
- **[Security](/introduction/security)** - Security practices for utilities
- **[Architecture](/introduction/cluster-architecture)** - How utilities fit into the overall design
