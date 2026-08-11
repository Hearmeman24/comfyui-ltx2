# Use multi-stage build with caching optimizations
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
   PIP_PREFER_BINARY=1 \
   PYTHONUNBUFFERED=1 \
   CMAKE_BUILD_PARALLEL_LEVEL=8 \
   HF_XET_HIGH_PERFORMANCE=1

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev \
        python3-pip \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 build-essential gcc && \
    \
    # make Python3.12 the default python & pip
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    \
    python3.12 -m venv /opt/venv && \
    \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu128

# Core Python tooling
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel

# Runtime libraries
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install pyyaml gdown triton jupyterlab jupyterlab-lsp \
        jupyter-server jupyter-server-terminals \
        ipykernel jupyterlab_code_formatter

# huggingface_hub (provides hf_hub_download + bundled hf_xet accelerator) is
# imported by src/hf_download_manager.py. The standalone `hf` CLI is installed
# separately for manual use / xet acceleration.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade huggingface_hub hf_xet
RUN curl -LsSf https://hf.co/cli/install.sh | bash

# ------------------------------------------------------------
# ComfyUI install — direct clone + pip install. Replaces comfy-cli,
# which used to clone the same repo and create a private .venv we then
# deleted anyway. Simpler, fewer indirection layers, no ~7 GB .venv.
#
# The ADD below fetches the current master ref from the GitHub API on
# every build; its content changes whenever ComfyUI master moves, which
# invalidates the clone layer. Without it, docker_layer_caching would
# keep serving the ComfyUI baked into the previous build's cache.
# ------------------------------------------------------------
ADD https://api.github.com/repos/comfyanonymous/ComfyUI/git/refs/heads/master /comfyui-master-ref.json
RUN --mount=type=cache,target=/root/.cache/pip \
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI \
    && pip install -r /ComfyUI/requirements.txt

FROM base AS final
# Make sure to use the virtual environment here too
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install opencv-python

# Same cache-bust trick as ComfyUI core, for the one custom node whose version
# actually gates a model release: LTX-2.5 support landed in ComfyUI-LTXVideo on
# 2026-08-11 (example_workflows/2.5/). Without this, docker_layer_caching serves
# the cached clone layer and a "rebuild" quietly ships the previous node.
ADD https://api.github.com/repos/Lightricks/ComfyUI-LTXVideo/git/refs/heads/master /ltxvideo-master-ref.json
RUN for repo in \
    https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    https://github.com/kijai/ComfyUI-KJNodes.git \
    https://github.com/rgthree/rgthree-comfy.git \
    https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    https://github.com/Jordach/comfy-plasma.git \
    https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    https://github.com/ClownsharkBatwing/RES4LYF.git \
    https://github.com/yolain/ComfyUI-Easy-Use.git \
    https://github.com/WASasquatch/was-node-suite-comfyui.git \
    https://github.com/theUpsider/ComfyUI-Logic.git \
    https://github.com/cubiq/ComfyUI_essentials.git \
    https://github.com/chrisgoringe/cg-image-picker.git \
    https://github.com/chflame163/ComfyUI_LayerStyle.git \
    https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git \
    https://github.com/Jonseed/ComfyUI-Detail-Daemon.git \
    https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git \
    https://github.com/bash-j/mikey_nodes.git \
    https://github.com/chrisgoringe/cg-use-everywhere.git \
    https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI.git \
    https://github.com/Lightricks/ComfyUI-LTXVideo.git \
    https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    https://github.com/M1kep/ComfyLiterals.git; \
    do \
        cd /ComfyUI/custom_nodes; \
        repo_dir=$(basename "$repo" .git); \
        if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
            git clone --recursive "$repo"; \
        else \
            git clone "$repo"; \
        fi; \
        if [ -f "/ComfyUI/custom_nodes/$repo_dir/requirements.txt" ]; then \
            pip install -r "/ComfyUI/custom_nodes/$repo_dir/requirements.txt"; \
        fi; \
        if [ -f "/ComfyUI/custom_nodes/$repo_dir/install.py" ]; then \
            python "/ComfyUI/custom_nodes/$repo_dir/install.py"; \
        fi; \
    done

# Force GPU onnxruntime. Several custom node requirements.txt files
# pull in plain `onnxruntime` (CPU) which shadows our GPU install
# because both packages provide the same `onnxruntime` Python module —
# last install wins. Reinstalling after the clone loop guarantees the
# image ships with the CUDA provider available.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip uninstall -y onnxruntime onnxruntime-gpu 2>/dev/null || true; \
    pip install onnxruntime-gpu

# ComfyUI-Manager. Cloned as lowercase `comfyui-manager` so it loads
# after the other custom_nodes (ComfyUI loads alphabetically — capital
# letters first), which is required for Manager to detect IMPORT FAILED
# states in earlier-loaded nodes.
RUN --mount=type=cache,target=/root/.cache/pip \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git \
        /ComfyUI/custom_nodes/comfyui-manager \
    && if [ -f /ComfyUI/custom_nodes/comfyui-manager/requirements.txt ]; then \
         pip install -r /ComfyUI/custom_nodes/comfyui-manager/requirements.txt; \
       fi

COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]