+++
title = "Self-Hosted Apps"
description = "Applications and services running in the homelab"
weight = 99
sort_by = "weight"

[extra]
+++

This section documents the applications and services self-hosted in the homelab. These range from productivity tools to personal projects, all deployed via GitOps and monitored continuously.

## Philosophy

### Why Self-Host?

Self-hosting provides unique challenges and rewards:

- **Reliability Engineering**: Running services you depend on creates real incentives for uptime
- **Data Ownership**: Complete control over data and privacy
- **Learning Opportunities**: Deep understanding of how services work
- **Cost Efficiency**: Leverage existing hardware instead of cloud subscriptions
- **Customization**: Tailor services to exact needs

### The Reality

> **Homelab Reality Check**: This is a homelab—if I overload the circuit by running too many appliances at once, the breaker trips and everything goes down. Despite these "real-world" constraints, it's a rewarding technical challenge to maximize uptime and maintain stability.

## Application Categories

### Productivity & Organization

- **[Vikunja](/self_hosting/vikunja)** - Task management and todo lists

### Databases & Data Services

- **[CloudNative PostgreSQL (CNPG)](/cnpg)** - Production-grade PostgreSQL on Kubernetes

### Communication & Messaging

- **[NATS](/nats)** - High-performance messaging system

## Deployment Pattern

All applications follow a consistent GitOps deployment pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Repository                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  App Config  │  │   Values     │  │   Secrets    │      │
│  │   (YAML)     │  │   (Helm)     │  │   (ESO)      │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼─────────────────┼─────────────────┼──────────────┘
          │                 │                 │
          └─────────────────┴─────────────────┘
                            │ GitOps Sync
┌───────────────────────────▼──────────────────────────────┐
│                       ArgoCD                               │
│              (Deployment Automation)                       │
└───────────────────────────┬──────────────────────────────┘
                            │ Apply
┌───────────────────────────▼──────────────────────────────┐
│                   Kubernetes Cluster                       │
│              (Application Runtime)                         │
└───────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Declarative Configuration**: Everything defined in YAML
2. **Version Control**: All changes tracked in Git
3. **Automated Sync**: ArgoCD applies changes automatically
4. **Secret Management**: External Secrets Operator handles credentials
5. **Monitoring**: All applications have metrics and health checks
6. **Backup Strategy**: Stateful apps use Longhorn snapshots

## Common Configuration

Most applications share similar configuration patterns:

### Storage

```yaml
# Persistent volume claim
persistence:
  enabled: true
  storageClass: longhorn-wdblack
  size: 10Gi
```

### Networking

```yaml
# Service and ingress
service:
  type: ClusterIP

ingress:
  enabled: true
  className: tailscale
```

### Resources

```yaml
# Resource limits
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
    cpu: 500m
```

## Adding New Applications

When adding a new application:

1. **Check Resources**: Review [Monitoring](/monitoring) for available capacity
2. **Plan Storage**: Determine if persistence is needed ([Storage](/storage))
3. **Configure Network**: Set up ingress and policies ([Networking](/networking))
4. **Secure Secrets**: Use [External Secrets Operator](/utils/eso) for credentials
5. **Add Monitoring**: Configure ServiceMonitor for metrics
6. **Document**: Update this section with app-specific details

## Troubleshooting

### Application Won't Start

```bash
# Check pod status
kubectl get pods -n <namespace>

# View logs
kubectl logs -n <namespace> <pod-name>

# Describe resource
kubectl describe pod -n <namespace> <pod-name>
```

### Storage Issues

- Check PVC status: `kubectl get pvc -n <namespace>`
- Verify Longhorn volumes: Access Longhorn UI
- Review storage class availability

### Network Connectivity

- Test service: `kubectl port-forward svc/<service> <port>:<port>`
- Check ingress: `kubectl get ingress -n <namespace>`
- Verify Cilium policies: `hubble observe --namespace <namespace>`

## Related Documentation

- **[CI/CD](/cicd)** - How applications are deployed
- **[Storage](/storage)** - Persistence configuration
- **[Networking](/networking)** - Service exposure and policies
- **[Security](/introduction/security)** - Best practices for app security
