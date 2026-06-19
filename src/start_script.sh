#!/usr/bin/env bash
# Image entrypoint. On container restarts the writable layer persists, so a
# plain `git clone` refuses to clone into the existing dir and we'd keep
# running the stale scripts from first boot. Always fetch + hard-reset to
# origin/main so the runtime scripts (start.sh, hf_download_manager.py,
# build_manifest.py, models_registry.json) reflect what's on the repo.
set -e
REPO_DIR=/comfyui-ltx2
REPO_URL=https://github.com/Hearmeman24/comfyui-ltx2.git
if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" fetch --depth=1 origin main
    git -C "$REPO_DIR" reset --hard origin/main
else
    rm -rf "$REPO_DIR"
    git clone --depth=1 "$REPO_URL" "$REPO_DIR"
fi
set +e
bash "$REPO_DIR/src/start.sh"
