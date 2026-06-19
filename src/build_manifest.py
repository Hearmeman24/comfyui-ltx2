#!/usr/bin/env python3
"""Emit an hf_download_manager manifest from models_registry.json.

The WAN template gates downloads by walking enabled workflow folders
(workflow_provisioner.py). This template ships a fixed model set instead, so we
queue registry entries directly — but a few entries carry lightweight selection
metadata so the legacy LTX-2 19b set can live in the registry too:

  - "flag": <env-var>   — entry is queued only when that flag env var is "true"
                          (e.g. download_ltx2_19b). No flag = always queued
                          (the default LTX-2.3 set).
  - "variant": full|fp8 — among entries sharing the same flag the fp8 one is
                          queued when lightweight_fp8=true, the full one
                          otherwise. Entries without a variant are unaffected.

Files already on disk above a 10 MB sanity threshold are skipped (same cutoff
the legacy bash downloader used: catches complete files, re-fetches
obviously-truncated ones). Non-HF models (e.g. the Oracle-hosted skin upscaler)
are NOT in the registry — hf_download_manager only speaks HF URLs, so those
stay as direct aria2c steps in start.sh, mirroring WAN.

Output: one `<url>\\t<dest_full_path>` line per model to --manifest.
Run the self-check with: python build_manifest.py --selftest
"""
import argparse
import json
import os
import sys
from pathlib import Path

MIN_OK_SIZE = 10 * 1024 * 1024  # 10 MB


def select(registry: dict, env: dict, lightweight_fp8: bool) -> dict:
    """Filter the registry by flag gating + fp8/full variant choice.

    - "flag": <env>        opt-IN  — kept only when env[flag] == "true".
    - "disable_flag": <env> opt-OUT — kept unless env[disable_flag] == "true"
                            (so it ships by default, e.g. the IC-LoRA set).
    - "variant": full|fp8  among variant-tagged entries, keep the fp8 one when
                            lightweight_fp8 else the full one.
    """
    enabled = {k for k, v in env.items() if v == "true"}
    gated = {
        n: e for n, e in registry.items()
        if ("flag" not in e or e["flag"] in enabled)
        and ("disable_flag" not in e or e["disable_flag"] not in enabled)
    }
    # Variant choice: among variant-tagged entries, keep only fp8 or full.
    want = "fp8" if lightweight_fp8 else "full"
    return {
        n: e for n, e in gated.items()
        if not e.get("variant") or e["variant"] == want
    }


def build(registry: dict, models_root: Path) -> tuple[list[str], list[str]]:
    lines, skipped = [], []
    for name in sorted(registry):
        entry = registry[name]
        dest = models_root / entry["subdir"] / name
        if dest.is_file() and dest.stat().st_size >= MIN_OK_SIZE:
            skipped.append(name)
        else:
            lines.append(f"{entry['url']}\t{dest}")
    return lines, skipped


def selftest() -> None:
    """skip-existing logic + subdir join + flag gating + variant choice."""
    import tempfile
    reg = {
        "big.safetensors": {"url": "https://h/big", "subdir": "loras/ltx2"},
        "missing.safetensors": {"url": "https://h/missing", "subdir": "vae"},
    }
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        big = root / "loras/ltx2/big.safetensors"
        big.parent.mkdir(parents=True)
        big.write_bytes(b"\0" * (MIN_OK_SIZE + 1))  # present + large -> skipped
        lines, skipped = build(reg, root)
        assert skipped == ["big.safetensors"], skipped
        assert lines == [f"https://h/missing\t{root / 'vae/missing.safetensors'}"], lines
        big.write_bytes(b"\0" * 10)  # truncated -> must re-queue
        lines2, skipped2 = build(reg, root)
        assert skipped2 == [] and len(lines2) == 2, (skipped2, lines2)

    # flag gating + variant selection
    greg = {
        "always.safetensors": {"url": "https://h/a", "subdir": "vae"},
        "gated_full.safetensors": {"url": "https://h/f", "subdir": "checkpoints",
                                   "flag": "download_ltx2_19b", "variant": "full"},
        "gated_fp8.safetensors": {"url": "https://h/8", "subdir": "checkpoints",
                                  "flag": "download_ltx2_19b", "variant": "fp8"},
        "gated_te.safetensors": {"url": "https://h/t", "subdir": "text_encoders",
                                 "flag": "download_ltx2_19b"},
    }
    off = select(greg, {"download_ltx2_19b": "false"}, lightweight_fp8=False)
    assert set(off) == {"always.safetensors"}, off
    on_full = select(greg, {"download_ltx2_19b": "true"}, lightweight_fp8=False)
    assert set(on_full) == {"always.safetensors", "gated_full.safetensors",
                            "gated_te.safetensors"}, on_full
    on_fp8 = select(greg, {"download_ltx2_19b": "true"}, lightweight_fp8=True)
    assert set(on_fp8) == {"always.safetensors", "gated_fp8.safetensors",
                           "gated_te.safetensors"}, on_fp8

    # disable_flag: opt-out — shipped by default, dropped when the env is "true"
    dreg = {
        "keep.safetensors": {"url": "https://h/k", "subdir": "loras"},
        "ic.safetensors": {"url": "https://h/i", "subdir": "loras",
                           "disable_flag": "disable_ic_loras"},
    }
    assert set(select(dreg, {}, False)) == {"keep.safetensors", "ic.safetensors"}
    assert set(select(dreg, {"disable_ic_loras": "true"}, False)) == {"keep.safetensors"}
    print("ok")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--registry", required=True)
    ap.add_argument("--models-root", required=True)
    ap.add_argument("--manifest", required=True)
    args = ap.parse_args()

    registry = json.loads(Path(args.registry).read_text())
    selected = select(
        registry,
        os.environ,
        lightweight_fp8=os.environ.get("lightweight_fp8") == "true",
    )
    lines, skipped = build(selected, Path(args.models_root))
    Path(args.manifest).write_text("\n".join(lines) + ("\n" if lines else ""))

    print(f"[build-manifest] {len(lines)} queued, {len(skipped)} already on disk")
    for n in skipped:
        print(f"  skip (present): {n}")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
    else:
        raise SystemExit(main())
