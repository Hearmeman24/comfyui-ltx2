# shellcheck shell=bash
# pre_launch hook for comfyui-ltx2 (CONTRACTS.md section 7).
# No shebang on purpose: this file is SOURCED, never executed.
#
# SOURCED by /comfyui-runtime/src/start.sh immediately before the ComfyUI
# launch. Sourcing rules: no `exit`, no `set -e`, runs on every boot and must
# be idempotent, own errors handled here.
#
# Pin kornia 0.8.2 before launch (ported from the pre-migration
# src/start.sh:466-469). ComfyUI-LTXVideo requires kornia unpinned and imports
# `pad` from kornia.geometry.transform.pyramid; kornia 0.8.3 removed that
# re-export, so the node fails to import ("cannot import name 'pad'"). 0.8.2
# is the last release that exposes it (needs only torch>=2.0.0). pip is a
# no-op once 0.8.2 is installed, and the base-owned PIP_CONSTRAINT keeps
# torch untouched.
if ! python3 -c "import kornia,sys; sys.exit(0 if kornia.__version__=='0.8.2' else 1)" 2>/dev/null; then
    echo "🔧 Pinning kornia==0.8.2 for ComfyUI-LTXVideo..."
    pip install "kornia==0.8.2" > /tmp/pip_kornia.log 2>&1 \
        || { echo "⚠️  kornia==0.8.2 install failed (see /tmp/pip_kornia.log); ComfyUI-LTXVideo nodes may not load."
             report_warn "kornia 0.8.2 pin failed; ComfyUI-LTXVideo nodes may not load"; }
fi
