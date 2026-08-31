# syntax=docker/dockerfile:1
# ============================================================================
# comfyui-ltx2 template image, built FROM the shared base
# (hearmeman/comfyui-base, comfyui-runtime/base/Dockerfile).
#
# The base owns: python 3.12 + /opt/venv (on PATH), the pinned torch trio +
# /torch-constraint.txt applied via ENV PIP_CONSTRAINT, pip tooling, pyyaml/
# gdown/triton/jupyterlab, huggingface_hub + hf_xet, opencv-python, ComfyUI
# pinned at COMFYUI_REF with /comfyui-approved-ref, ComfyUI-Manager, both
# SageAttention wheels under /opt/sage/, the CivitAI downloader, and
# ENV ORT_INDEX_ARGS (the per-CUDA-variant onnxruntime index nuance).
#
# This layer adds ONLY the ltx2 node set, the onnxruntime-gpu reassert, and
# the entrypoint. BASE_IMAGE is passed by CI from pins.json's "base_image";
# the default below mirrors that pin so a plain build stays coherent.
# ============================================================================
ARG BASE_IMAGE=hearmeman/comfyui-base:cu130-comfy0.34.0-torch2.11.0
FROM ${BASE_IMAGE}

# Cache-bust for the one custom node whose version actually gates a model
# release: LTX-2.5 support landed in ComfyUI-LTXVideo on 2026-08-11
# (example_workflows/2.5/). The ADD fetches the current master ref from the
# GitHub API on every build, invalidating the clone-loop layer whenever
# upstream moves. Without it, docker_layer_caching serves the cached clone
# layer and a "rebuild" quietly ships the previous node.
ADD https://api.github.com/repos/Lightricks/ComfyUI-LTXVideo/git/refs/heads/master /ltxvideo-master-ref.json

# The ltx2 node set, culled 2026-08-13 to the packs the 10 shipped workflows
# actually resolve nodes from, plus the Tier 1 packs kept on every template
# (rgthree-comfy for its UI layer, ComfyUI-Openrouter_node for LLM prompt
# assist; its API key is user-supplied via widget, LLM_KEY, or a JSON file in
# the node dir, never baked). The three HEAD-trackers (WhatDreamsCost-ComfyUI,
# BFSNodes, VHS) are ALSO in template.json's custom_nodes.repos: the runtime's
# clone loop finds the baked dir and takes its `git pull --ff-only` branch
# (comfyui-runtime/src/start.sh:450-453), so they keep tracking upstream HEAD
# at boot with no dual clone.
# PIP_CONSTRAINT (base-owned) applies to every requirements install below.
RUN for repo in \
    https://github.com/kijai/ComfyUI-KJNodes.git \
    https://github.com/rgthree/rgthree-comfy.git \
    https://github.com/cubiq/ComfyUI_essentials.git \
    https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI.git \
    https://github.com/Lightricks/ComfyUI-LTXVideo.git \
    https://github.com/alisson-anjos/ComfyUI-BFSNodes.git \
    https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    https://github.com/gabe-init/ComfyUI-Openrouter_node.git; \
    do \
        cd /ComfyUI/custom_nodes; \
        repo_dir=$(basename "$repo" .git); \
        git clone "$repo"; \
        if [ -f "/ComfyUI/custom_nodes/$repo_dir/requirements.txt" ]; then \
            pip install -r "/ComfyUI/custom_nodes/$repo_dir/requirements.txt"; \
        fi; \
        if [ -f "/ComfyUI/custom_nodes/$repo_dir/install.py" ]; then \
            python "/ComfyUI/custom_nodes/$repo_dir/install.py"; \
        fi; \
    done

# Force GPU onnxruntime. Several node requirements pull in plain `onnxruntime`
# (CPU), which shadows the GPU install because both provide the same
# `onnxruntime` module and last install wins. This reassert therefore comes
# AFTER the clone loop, and no later RUN may pip install anything
# (comfyui-runtime base Dockerfile, onnxruntime ordering trap). ORT_INDEX_ARGS
# is base-owned data: the Azure onnxruntime-cuda-12 index on cu128, empty on
# cu130 where PyPI's onnxruntime-gpu links CUDA 13.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip uninstall -y onnxruntime onnxruntime-gpu 2>/dev/null || true; \
    pip install onnxruntime-gpu $ORT_INDEX_ARGS

# Build-time gate: the shipped image must expose the CUDA provider. Provider
# enumeration is import-only and works with no GPU present, so this fails the
# CI build, not a customer pod. The runtime repo's CI greps template
# Dockerfiles for this CUDAExecutionProvider assertion.
RUN python3 -c "import onnxruntime; p = onnxruntime.get_available_providers(); assert 'CUDAExecutionProvider' in p, p; print('onnxruntime providers OK:', p)"

COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]
