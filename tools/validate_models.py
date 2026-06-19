#!/usr/bin/env python3
"""CI validator for the LTX-2.3 model registry.

Two checks, both fatal on failure:
  1. Workflow JSON validity — every workflows/**/*.json must parse.
  2. Registry reachability — every URL in src/models_registry.json must
     answer 200/301/302 to a HEAD (falls back to a 1-byte ranged GET for
     hosts that reject HEAD).

Coverage (every workflow-referenced model is provisioned) is deliberately
NOT enforced: the legacy LTX-2 19b workflows reference models fetched by the
gated bash path in start.sh, not the registry, so a coverage check here is
pure noise. Reachability is the signal that actually prevents broken builds.

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
    wf_errors = check_workflows()
    for e in wf_errors:
        print(f"❌ {e}")

    registry = json.loads(REGISTRY.read_text())
    jobs = [(n, e["url"], bool(e.get("gated"))) for n, e in registry.items()]
    gated_n = sum(1 for *_, g in jobs if g)
    print(f"🔎 checking {len(jobs)} registry URLs ({gated_n} gated, 401/403 tolerated)...")
    with ThreadPoolExecutor(max_workers=8) as pool:
        url_errors = [r for r in pool.map(check_url, jobs) if r]
    for e in url_errors:
        print(f"❌ unreachable: {e}")

    total = len(wf_errors) + len(url_errors)
    if total:
        print(f"\n💥 {total} problem(s) found")
        return 1
    print(f"✅ {len(jobs)} URLs reachable, all workflows valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
