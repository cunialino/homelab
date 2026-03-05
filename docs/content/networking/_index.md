+++
title = "Networking"
description = "Networking setup"
weight = 3
sort_by = "weight"

[extra]
+++

Clusters, computers and apps are useless without networking.

It is important to get internal communication right in order to make my own
apps to work, and it is crucial to get external networking right for security
reasons.

In my homelab, I leverage [Cilium](https://cilium.io/) as my Container Network Interface (CNI) for high-performance and secure internal cluster communication. For external access and secure remote management, I utilize [Tailscale](https://tailscale.com/) to create a private network across my devices.

For multi-node k3s cluster high availability, I use [kube-vip](/networking/kube_vip/) to provide load balancing for the control plane and service traffic.

I do not host publicly available sites, I am able to access my own services
with a VPN.
