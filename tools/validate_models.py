#!/usr/bin/env python3
"""CI / pre-push validator for the LTX-2.3 model registry.

Offline checks (always run; used by the pre-push hook):
  1. Workflow JSON validity — every workflows/**/*.json must parse.
  2. Coverage — every .safetensors a workflow references (top-level nodes AND
     subgraph definitions) must exist as a key in src/models_registry.json.
     Catches a workflow pointing at a model nothing provisions (red node at
     runtime) — e.g. a workflow wanting the int8-convrot weights while the
     registry downloads bf16.

Network check (skipped with --offline):
  3. Registry reachability — every URL in src/models_registry.json must
     answer 200/301/302 to a HEAD (falls back to a 1-byte ranged GET for
     hosts that reject HEAD).

Coverage scopes to registry-provisioned workflows. The legacy LTX-2 19b
workflows in workflows/legacy_19b/ reference models fetched by the gated bash
path in start.sh (not the registry), so enforcing coverage there is pure noise.

Stdlib only — no pip install needed in CI.
"""
import json
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
REGISTRY = REPO / "src" / "models_registry.json"
WORKFLOWS = REPO / "workflows"
TIMEOUT = 30
OK = {200, 301, 302}
UA = {"User-Agent": "ltx2-template-validator/1.0"}


def check_workflows() -> list[str]:
    errors = []
    for wf in sorted(WORKFLOWS.rglob("*.json")):
        try:
            json.loads(wf.read_text())
        except Exception as e:
            errors.append(f"invalid JSON: {wf.relative_to(REPO)}: {e}")
    return errors


def _workflow_model_refs(wf_json: dict) -> set[str]:
    refs = set()
    # Loaders increasingly live inside subgraph definitions rather than the
    # top-level node list (the LTX-2.5 workflows keep every loader in one), so
    # walk both or coverage silently checks nothing.
    groups = [wf_json.get("nodes", [])]
    groups += [sg.get("nodes", []) for sg in
               (wf_json.get("definitions", {}) or {}).get("subgraphs", [])]
    for nodes in groups:
        for node in nodes:
            for w in (node.get("widgets_values") or []):
                if isinstance(w, str) and w.endswith(".safetensors"):
                    refs.add(w)
    return refs


def check_coverage(registry: dict) -> list[str]:
    # Every registry-provisioned workflow — top-level plus subdirs like LTX2.5/.
    # legacy_19b/ is excluded: it's bash-provisioned (see module docstring).
    errors = []
    for wf in sorted(WORKFLOWS.rglob("*.json")):
        if "legacy_19b" in wf.parts:
            continue
        try:
            data = json.loads(wf.read_text())
        except Exception:
            continue  # invalid JSON already reported by check_workflows
        for model in sorted(_workflow_model_refs(data)):
            # Registry keys are basenames; a model in a subdir (e.g. loras/ltx2)
            # is referenced in the workflow with its subfolder prefix
            # ("ltx2/foo.safetensors"), so match on basename.
            name = Path(model).name
            if name not in registry:
                errors.append(f"{wf.relative_to(REPO)} references '{model}' — not in models_registry.json")
                continue
            # ...but the prefix has to be right. ComfyUI resolves a widget value
            # relative to the category root, so "vae/foo.safetensors" for a model
            # that sits in models/vae/ becomes models/vae/vae/foo.safetensors and
            # shows up as a missing model. Only a genuine subfolder belongs in the
            # prefix: registry subdir "vae" -> "", "loras/ltx2" -> "ltx2".
            want = "/".join(registry[name]["subdir"].split("/")[1:])
            got = str(Path(model).parent) if "/" in model else ""
            if got != want:
                shown = f"'{want}/{name}'" if want else f"'{name}'"
                errors.append(
                    f"{wf.relative_to(REPO)} references '{model}' — wrong folder prefix; "
                    f"ComfyUI resolves it under models/{registry[name]['subdir']}/. Use {shown}.")
    return errors


def _status(url: str, method: str) -> int:
    req = urllib.request.Request(url, method=method, headers=dict(UA))
    if method == "GET":
        req.add_header("Range", "bytes=0-0")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.status


def check_url(job: tuple[str, str, bool]) -> str | None:
    name, url, gated = job
    # Gated repos (gated: auto on HF) answer 401/403 to unauthenticated CI;
    # that still confirms the path resolves to a real gated file, so accept it.
    ok = OK | {401, 403} if gated else OK
    for method in ("HEAD", "GET"):
        try:
            if _status(url, method) in ok:
                return None
        except urllib.error.HTTPError as e:
            if e.code in ok:
                return None
            last = f"HTTP {e.code}"
        except Exception as e:  # noqa: BLE001
            last = str(e)
    return f"{name}: {last} — {url}"


def main() -> int:
    offline = "--offline" in sys.argv[1:]
    registry = json.loads(REGISTRY.read_text())

    wf_errors = check_workflows()
    cov_errors = check_coverage(registry)
    for e in wf_errors + cov_errors:
        print(f"❌ {e}")

    url_errors = []
    if offline:
        print("⏭️  --offline: skipping registry URL reachability check.")
    else:
        jobs = [(n, e["url"], bool(e.get("gated"))) for n, e in registry.items()]
        gated_n = sum(1 for *_, g in jobs if g)
        print(f"🔎 checking {len(jobs)} registry URLs ({gated_n} gated, 401/403 tolerated)...")
        with ThreadPoolExecutor(max_workers=8) as pool:
            url_errors = [r for r in pool.map(check_url, jobs) if r]
        for e in url_errors:
            print(f"❌ unreachable: {e}")

    total = len(wf_errors) + len(cov_errors) + len(url_errors)
    if total:
        print(f"\n💥 {total} problem(s) found")
        return 1
    reach = "skipped" if offline else f"{len(registry)} URLs reachable"
    print(f"✅ all workflows valid, every referenced model in registry, {reach}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
