#!/usr/bin/env python3
"""Generate a review candidate from local source, checking every embedded script.

An artifact manifest is not a malware scan or permission to bypass antivirus.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from place_format import FormatError, PlaceBuilder, atomic_write

ROOT = Path(__file__).resolve().parents[1]


def build(output: Path, smoke_test: bool = False, project_root: Path = ROOT) -> Path:
    output = output.absolute()
    if output.suffix != ".rbxlx":
        raise FormatError("The output must be a .rbxlx file")
    resolved = output.resolve()
    if resolved.is_relative_to(project_root.resolve() / "src") or resolved.is_relative_to(project_root.resolve() / ".git"):
        raise FormatError("Output must not overwrite source or Git metadata")
    builder = PlaceBuilder(project_root)
    payload = builder.render(smoke_test=smoke_test)
    manifest = builder.manifest(payload)
    atomic_write(output, payload)
    report = Path(str(output) + ".manifest.json")
    atomic_write(report, (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/review/ZUMBI-Candidata.rbxlx")
    parser.add_argument("--smoke-test", action="store_true", help="Include Studio tests in an isolated DataStore namespace")
    args = parser.parse_args()
    result = build(args.output, smoke_test=args.smoke_test)
    print(f"Generated {result} ({result.stat().st_size:,} bytes)")
    print("XML/source correspondence passed. ANTIVIRUS NOT RUN; DEFENDER ALERT UNRESOLVED.")
