+++
title = "Introduction"
description = "Welcome to my homelab documentation - a guide to my self-hosted Kubernetes environment and technical experiments"
weight = 1
sort_by = "weight"

[extra]
+++

My homelab is a bare metal k3s cluster running on my mini-pc and some spare
hardware I happened to have.

## Hardware

Currently everything runs on the following hardware:

- AOOSTAR gem 12:

    - RAM: 64GB
    - CPU: [amd ryzen 7 8845hs](https://www.amd.com/en/products/processors/laptop/ryzen/8000-series/amd-ryzen-7-8845hs.html)
    - disks:
        - 1 TB SSD Samsung EVO
        - 2 TB SSD wd black

- orange pi zero 3:
    
    - RAM: 2GB
    - CPU: Allwinner H618

- asus zenbook 20215:

    - RAM: 8GB
    - CPU: intel i7

- hp elite desk G2:
    
    - RAM: 16GB
    - CPU: intel 15


## Software

All the nodes run on nixos, which makes it much easier to keep the aligned.
Dotfiles are available [here](https://github.com/cunialino/dotfiles)


#### Disclaimer: vibe-documenting

Most of the docs in this site are generated with the gemini-cli agent and reviewed by myself.

I spend most of my time coding, which is my passion and hobby, hence I try
to cut some corners on other things.
