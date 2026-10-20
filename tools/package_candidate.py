#!/usr/bin/env python3
"""Package a source-matched review candidate; never upload or run its scripts."""
from __future__ import annotations

import argparse
from io import BytesIO
import json
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

from place_format import FormatError, PlaceBuilder, atomic_write

ROOT = Path(__file__).resolve().parents[1]
NOTICE = """REVIEW CANDIDATE - NOT CLEARED BY ANTIVIRUS

This package contains a Roblox XML place and its source-integrity manifest.
The original package triggered Windows Defender Trojan:Script/Ulthar.A!ml.
The cause remains unresolved. No antivirus scan or Roblox engine test was
performed on this candidate in the Linux build environment.
Keep Windows Defender enabled. Do not bypass a quarantine or detection.
"""


def package(output: Path, project_root: Path = ROOT) -> dict:
    if output.suffix != ".zip":
        raise FormatError("Candidate output must end in .zip")
    resolved = output.resolve()
    if resolved.is_relative_to(project_root.resolve() / "src") or resolved.is_relative_to(project_root.resolve() / ".git"):
        raise FormatError("Output must not overwrite source or Git metadata")
    builder = PlaceBuilder(project_root)
    place = builder.render()
    manifest = builder.manifest(place)
    files = {
        "ZUMBI-Ultimo-Voo.rbxlx": place,
        "MANIFEST.json": (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
        "READ-ME.txt": NOTICE.encode("utf-8"),
    }
    buffer = BytesIO()
    with ZipFile(buffer, "w") as archive:
        for name, payload in files.items():
            info = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100600 << 16
            archive.writestr(info, payload)
    with ZipFile(BytesIO(buffer.getvalue())) as archive:
        if archive.testzip() is not None or archive.namelist() != list(files):
            raise FormatError("ZIP integrity check failed")
        for name, payload in files.items():
            if archive.read(name) != payload:
                raise FormatError("ZIP content differs from validated source")
    atomic_write(output.absolute(), buffer.getvalue())
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/review/ZUMBI-Candidata.zip")
    args = parser.parse_args()
    result = package(args.output)
    print(f"Candidate packaged: {args.output}; place SHA-256 {result['place_sha256']}")
    print("ANTIVIRUS NOT RUN. This is not a cleared replacement for the flagged file.")
