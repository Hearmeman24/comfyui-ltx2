#!/usr/bin/env bash
# Image entrypoint. On container restarts the writable layer persists, so a
# plain `git clone` refuses to clone into the existing dir and we'd keep
# running the stale scripts from first boot. Always fetch + hard-reset to
# origin/main so the runtime scripts (start.sh, hf_download_manager.py,
# build_manifest.py, models_registry.json) reflect what's on the repo.

# Preflight: RunPod's Global Networking option blocks this pod's outbound DNS,
# so the sync below dies with "Could not resolve host: github.com" and sends
# people looking at GitHub instead of at the pod setting. Fail fast and name it.
if ! timeout 5 getent hosts github.com >/dev/null 2>&1 &&
   ! timeout 5 getent hosts huggingface.co >/dev/null 2>&1; then
    cat >&2 <<'EOF'
================================================================================
❌ This pod cannot resolve github.com or huggingface.co. It has no outbound DNS.

Global networking is almost certainly enabled on this pod, and it blocks the
repo sync and every model download. Disable it in the RunPod pod settings:
terminate this pod, deploy it again, and switch "Global Networking" OFF in the
pod configuration before you hit deploy (it cannot be changed on a running pod).

Nothing was downloaded and ComfyUI was not started.
================================================================================
EOF
    exit 1
fi

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
cp -f "$REPO_DIR/src/start.sh" /
cp -f "$REPO_DIR/src/hf_download_manager.py" /
cp -f "$REPO_DIR/src/build_manifest.py" /
cp -f "$REPO_DIR/src/models_registry.json" /
bash /start.sh
