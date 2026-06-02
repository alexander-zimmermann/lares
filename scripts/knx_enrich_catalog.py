#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Project-specific enrichment of the raw ga-catalog.yaml.

The upstream `knxproj-to-yaml` tool (in the knx-nats-bridge repo) only
emits what ETS itself defines. This post-processor adds the conventions
specific to this project's ETS naming:

* Normalise ETS Building-style room names (`4 - LivingRoom (E4)` ->
  `LivingRoom`) so they match GA-name segments.
* Drop ETS auto-generated descriptions that just repeat
  ``<space-name> <function-name>`` — they carry no real information.

Run in-place over the file produced by `knxproj-to-yaml`.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

import yaml

# Strip ETS' Building-numbering style: `4 - LivingRoom (E4)` -> `LivingRoom`.
# Keeps the inner name only; leaves anything that doesn't match untouched.
_ROOM_NORMALISE_RE = re.compile(r"^\s*\d+\s*-\s*(.+?)\s*\([^)]*\)\s*$")


def _normalise_room(room: str) -> str:
    m = _ROOM_NORMALISE_RE.match(room)
    return m.group(1).strip() if m else room.strip()


def _is_auto_description(desc: str, room: str | None, function: str | None) -> bool:
    """Detect ETS auto-generated `<space> <function>` descriptions.

    ETS prefills a Function's description with the space-name + the
    function-name in either of two forms:

        "<room> <function>"
        "<n> - <room> (<id>) <function>"   (Building-numbered style)

    Both add no information beyond what room/function already carry, so we
    drop them. Comparison is case-insensitive and whitespace-tolerant.
    """
    if not desc:
        return False
    norm = " ".join(desc.split()).lower()
    parts: list[str] = []
    if room:
        parts.append(room.strip().lower())
    if function:
        parts.append(function.strip().lower())
    if norm == " ".join(parts):
        return True
    if room and function:
        pattern = re.compile(
            r"^\s*\d+\s*-\s*"
            + re.escape(room.strip())
            + r"\s*\([^)]*\)\s+"
            + re.escape(function.strip())
            + r"\s*$",
            re.IGNORECASE,
        )
        if pattern.match(desc.strip()):
            return True
    return False


def enrich(catalog: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for ga, entry in catalog.items():
        if not isinstance(entry, dict):
            out[ga] = entry
            continue
        e = dict(entry)

        # Match ETS auto-descriptions BEFORE normalising the room — the
        # boilerplate uses the raw ETS-Building-style room name
        original_room = e.get("room")
        normalised_room = _normalise_room(str(original_room)) if original_room else None
        desc = str(e.get("description") or "")
        candidates = [r for r in (original_room, normalised_room) if r]
        if desc and any(
            _is_auto_description(desc, r, e.get("function")) for r in candidates
        ):
            del e["description"]

        if normalised_room is not None:
            e["room"] = normalised_room

        out[ga] = e
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Apply project-specific enrichment to a raw ga-catalog.yaml"
    )
    parser.add_argument("path", type=Path, help="Path to ga-catalog.yaml (modified in place)")
    args = parser.parse_args(argv)

    raw = yaml.safe_load(args.path.read_text(encoding="utf-8")) or {}
    if not isinstance(raw, dict):
        print(f"error: {args.path} top-level must be a mapping", file=sys.stderr)
        return 2

    enriched = enrich(raw)

    args.path.write_text(
        yaml.safe_dump(enriched, sort_keys=True, allow_unicode=True, default_flow_style=False),
        encoding="utf-8",
    )

    total = len(enriched)
    with_room = sum(1 for e in enriched.values() if isinstance(e, dict) and "room" in e)
    with_function = sum(1 for e in enriched.values() if isinstance(e, dict) and "function" in e)
    with_description = sum(
        1 for e in enriched.values() if isinstance(e, dict) and "description" in e
    )
    print(
        f"enriched {total} entries (room={with_room}, "
        f"function={with_function}, description={with_description})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
