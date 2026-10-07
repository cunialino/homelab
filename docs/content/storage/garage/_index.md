+++
title = "Garage"
weight = 2
sort_by = "weight"
+++

[Garage](https://garagehq.deuxfleurs.fr/) is a lightweight s3 object storage I deployed in my homelab.

I chose garage for its reliability after minio was archived.

I also considered rustfs, but it is not as mature and was giving me OOM errors
when running queries on it.

## Configuration

I deploy Garage via [ArgoCD](/cicd/argocd/), with its Application definition at
[apps/garage.yaml](https://github.com/cunialino/homelab/tree/main/apps/garage.yaml)
and configuration at [base/garage/](https://github.com/cunialino/homelab/tree/main/base/garage/).

API keys and the admin token are provisioned via an ExternalSecret from Bitwarden
Secrets Manager.

## LoadBalancer VIP

Garage is exposed to the LAN as a `type: LoadBalancer` service. Instead of
relying on an external cloud load balancer, I let Cilium announce a stable
virtual IP (VIP) on my LAN using L2 ARP announcements.

### How it works

Cilium owns the `LoadBalancer` service IPs through an IP pool. I reserve a
fixed IP for Garage and tell Cilium which node and network interface should
announce it:

1. **IP pool** — [`base/cilium/lb-ip-pool.yaml`](https://github.com/cunialino/homelab/tree/main/base/cilium/lb-ip-pool.yaml)
   defines the range `192.168.0.200-192.168.0.254` that Cilium may hand out.
2. **L2 announcement policy** — [`base/garage/cilium-l2.yaml`](https://github.com/cunialino/homelab/tree/main/base/garage/cilium-l2.yaml)
   (`CiliumL2AnnouncementPolicy`) binds the `garage` service to the node
   `elcungem` and announces it on the matching interfaces (`eth*`, `enp*`,
   `eno*`, `ens*`, `end*`).
3. **Service** — [`base/garage/service.yaml`](https://github.com/cunialino/homelab/tree/main/base/garage/service.yaml)
   requests the fixed IP `192.168.0.200` through the
   `lbipam.cilium.io/ips` annotation.

```yaml
# base/garage/service.yaml
metadata:
  name: garage-svc
  annotations:
    lbipam.cilium.io/ips: "192.168.0.200"
spec:
  type: LoadBalancer
  ports:
    - name: s3-api
      port: 3900
    - name: rpc
      port: 3901
    - name: admin
      port: 3903
```

### Why L2

A `CiliumL2AnnouncementPolicy` makes a single node answer ARP for the VIP with
its own MAC address. This is simple and reliable for a single-object-store
service on a small LAN: traffic to `192.168.0.200` always lands on `elcungem`,
where Garage runs. It trades automatic failover for predictability, which is
the right call for a workload that lives on one node.

The VIP is the address I point my S3 clients and Garage admin UI at.
