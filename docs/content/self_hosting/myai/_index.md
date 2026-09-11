+++
title = "myai"
weight = 2
sort_by = "weight"

[extra]
+++

[myai](https://cunialino.github.io/myai/) is my AI / LLM serving stack. It
runs on **elcunhalo**, a standalone Strix Halo machine (Ryzen AI Max+ 395,
128 GB unified memory) that is not part of the k3s cluster — the cluster and
the other LAN machines consume its GPU as an external service over
`192.168.0.6`.

It exposes llama.cpp (OpenAI-compatible API on port 11434) and ComfyUI (port
8188), all on ROCm 10 inside rootless podman containers.

Full documentation — ROCm packaging, container builds, model management —
lives in the [myai docs](https://cunialino.github.io/myai/).
