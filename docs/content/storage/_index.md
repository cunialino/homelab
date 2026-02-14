+++
title = "Storage"
description = "Storage solutions for the homelab including distributed block storage and network file sharing"
weight = 4
sort_by = "weight"

[extra]
+++

Reliable and performant storage is a critical component of any Kubernetes cluster. This section documents the storage solutions used in this homelab.

## Overview

The homelab uses a multi-tiered storage approach:

- **[Longhorn](/storage/longhorn)** - Distributed block storage for stateful workloads
- **[RustFS](/storage/rustfs)** - Network file system for shared data access

## Storage Architecture

### Block Storage (Longhorn)

Longhorn provides highly available, persistent storage for Kubernetes workloads:

- **Distributed**: Data replicated across multiple nodes for redundancy
- **Snapshots**: Point-in-time backups for disaster recovery
- **Thin provisioning**: Efficient storage utilization
- **Kubernetes native**: Integrated via StorageClass resources

### Network Storage (RustFS)

RustFS offers flexible file sharing across the network:

- **NFS-compatible**: Works with standard NFS clients
- **Cross-platform**: Accessible from various operating systems
- **Lightweight**: Minimal resource overhead

## Choosing Storage

| Use Case | Recommended Solution |
|----------|---------------------|
| Databases (PostgreSQL, etc.) | Longhorn |
| Application data | Longhorn |
| Shared configuration files | RustFS |
| Media/content sharing | RustFS |
| Backup storage | Longhorn (with snapshots) |

## Related Documentation

- **[CNPG](/cnpg)** - CloudNative PostgreSQL uses Longhorn for database storage
- **[Monitoring](/monitoring)** - Grafana and Prometheus use Longhorn for persistence
- **[Self-Hosted Apps](/self_hosting)** - Applications configure storage in their manifests

## Configuration

Storage is configured through:
- Kubernetes StorageClasses (defined in application manifests)
- PersistentVolumeClaims (requested by applications)
- Longhorn UI for management and snapshots
