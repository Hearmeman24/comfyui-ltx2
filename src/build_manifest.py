#!/usr/bin/env python3
"""Emit an hf_download_manager manifest from models_registry.json.

The WAN template gates downloads by walking enabled workflow folders
(workflow_provisioner.py). This template ships a single fixed model set, so
there is nothing to gate — every registry entry is queued. Files already on
disk above a 10 MB sanity threshold are skipped (same cutoff the legacy bash
downloader used: catches complete files, re-fetches obviously-truncated ones).

Output: one `<url>\\t<dest_full_path>` line per model to --manifest.
Run the self-check with: python build_manifest.py --selftest
"""
import argparse
import json
import sys
from pathlib import Path

MIN_OK_SIZE = 10 * 1024 * 1024  # 10 MB


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
    """skip-existing logic + subdir join."""
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
    print("ok")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--registry", required=True)
    ap.add_argument("--models-root", required=True)
    ap.add_argument("--manifest", required=True)
    args = ap.parse_args()

    registry = json.loads(Path(args.registry).read_text())
    lines, skipped = build(registry, Path(args.models_root))
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
