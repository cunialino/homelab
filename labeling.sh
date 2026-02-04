#!/usr/bin/env bash

# I use this script to "declarative" label my nodes, better than dotfiles
#
#
kubectl taint nodes opizero3 opi=ok:NoSchedule --overwrite

kubectl label nodes elcungem node.longhorn.io/create-default-disk='config' --overwrite
kubectl label nodes elcunhp1 node.longhorn.io/create-default-disk='config' --overwrite


kubectl label node elcunal nats-group=core-ha --overwrite
kubectl label node elcungem nats-group=core-ha --overwrite
kubectl label node elcunhp1 nats-group=core-ha --overwrite



# Need to change reserved storage on ui, does not work from here
kubectl annotate node elcungem \
  node.longhorn.io/default-disks-config='[{"path":"/second_disk","allowScheduling":false,"storageReserved":0,"name":"wd_black_gem","tags":["wd_black"]}]' \
  --overwrite

kubectl annotate node elcunhp1 \
  node.longhorn.io/default-disks-config='[{"path":"/second_disk","allowScheduling":false,"storageReserved":0,"name":"wd_black_hp1","tags":["wd_black"]}]' \
  --overwrite


kubectl label node elcungem streaming=true --overwrite
kubectl label node elcunal streaming=true --overwrite


kubectl label node elcungem internet=true --overwrite
kubectl label node elcunhp1 internet=true --overwrite

kubectl label node elcungem fast-eth=true --overwrite
kubectl label node elcunhp1 fast-eth=true --overwrite
kubectl label node opizero3 fast-eth=true --overwrite



kubectl annotate node elcungem node.longhorn.io/default-node-tags='["storage","fast"]'
kubectl annotate node elcunhp1 node.longhorn.io/default-node-tags='["fast"]'
