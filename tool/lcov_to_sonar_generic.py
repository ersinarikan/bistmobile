#!/usr/bin/env python3
"""Convert Flutter lcov.info → Sonar generic coverage XML."""

from __future__ import annotations

import argparse
import os
from collections import defaultdict
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--lcov",
        default="coverage/lcov.info",
        help="Input lcov path",
    )
    parser.add_argument(
        "--out",
        default="coverage/sonar-generic-coverage.xml",
        help="Output Sonar generic coverage XML",
    )
    parser.add_argument(
        "--strip-prefix",
        default="",
        help="Optional absolute prefix to strip from SF paths",
    )
    args = parser.parse_args()

    root = Path.cwd()
    lcov_path = Path(args.lcov)
    if not lcov_path.is_file():
        raise SystemExit(f"missing lcov: {lcov_path}")

    strip = args.strip_prefix or ""
    # Flutter often emits absolute SF= paths.
    if not strip:
        strip = f"{root}/"

    files: dict[str, dict[int, bool]] = defaultdict(dict)
    current: str | None = None

    for raw in lcov_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if line.startswith("SF:"):
            path = line[3:]
            if strip and path.startswith(strip):
                path = path[len(strip) :]
            # Prefer repo-relative lib/… paths
            if "/lib/" in path and not path.startswith("lib/"):
                path = path[path.index("lib/") :]
            current = path
        elif line.startswith("DA:") and current:
            # DA:<line>,<hits>
            try:
                num_s, hits_s = line[3:].split(",", 1)
                num = int(num_s)
                hits = int(hits_s)
            except ValueError:
                continue
            prev = files[current].get(num, False)
            files[current][num] = prev or hits > 0
        elif line == "end_of_record":
            current = None

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    parts = ['<?xml version="1.0" encoding="UTF-8"?>', '<coverage version="1">']
    for path in sorted(files):
        if not path.startswith("lib/"):
            continue
        parts.append(f'  <file path="{path}">')
        for num in sorted(files[path]):
            covered = "true" if files[path][num] else "false"
            parts.append(
                f'    <lineToCover lineNumber="{num}" covered="{covered}"/>'
            )
        parts.append("  </file>")
    parts.append("</coverage>")
    out.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"wrote {out} files={sum(1 for p in files if p.startswith('lib/'))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
