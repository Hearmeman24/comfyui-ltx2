#!/usr/bin/env python3
"""Shim: run the shared runtime's model validator against this repo.

The real validator lives in comfyui-runtime/tools/validate_models.py (the
reconciled family superset: registry/workflow coverage incl. subgraphs and
folder prefixes, HF model-API existence checks that follow repo renames,
ranged-GET size checks). This shim fetches comfyui-runtime at the exact
`runtime_ref` pinned in pins.json, so CI and the pre-push hook validate
against the runtime this template actually boots, not whatever sits on the
runtime's main.

Extra args (e.g. --offline, used by .githooks/pre-push) pass straight through.

Stdlib only.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RUNTIME_URL = "https://github.com/Hearmeman24/comfyui-runtime.git"
# Reuse one cached clone across runs (pre-push calls this on every push).
CACHE = Path.home() / ".cache" / "comfyui-runtime-validator"


def _git(*args: str) -> None:
    subprocess.run(["git", "-C", str(CACHE), *args], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def resolve_runtime(ref: str) -> Path:
    if not (CACHE / ".git").is_dir():
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "--quiet", RUNTIME_URL, str(CACHE)],
                       check=True)
    # Fetch only when the pinned ref is not already local, so the offline
    # pre-push path stays offline once the ref has been seen.
    try:
        _git("rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}")
    except subprocess.CalledProcessError:
        _git("fetch", "--quiet", "origin", ref)
        ref = "FETCH_HEAD"
    _git("checkout", "--quiet", "--force", ref)
    return CACHE


def main() -> int:
    # COMFYUI_RUNTIME_DIR points at a local runtime checkout, used AS IS (no
    # git ops on it), for working on the two repos side by side.
    local = os.environ.get("COMFYUI_RUNTIME_DIR")
    if local:
        runtime = Path(local)
    else:
        ref = json.loads((REPO / "pins.json").read_text())["runtime_ref"]
        try:
            runtime = resolve_runtime(ref)
        except subprocess.CalledProcessError as e:
            print(f"FATAL: could not fetch comfyui-runtime at runtime_ref {ref!r}: {e}")
            return 1
    cmd = [sys.executable, str(runtime / "tools" / "validate_models.py"),
           "--registry", str(REPO / "src" / "models_registry.json"),
           "--workflows", str(REPO / "workflows"),
           "--template", str(REPO / "template.json"),
           *sys.argv[1:]]
    return subprocess.run(cmd).returncode


if __name__ == "__main__":
    raise SystemExit(main())
