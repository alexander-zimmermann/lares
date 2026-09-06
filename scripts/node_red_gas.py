"""List the group addresses Node-Red's flows touch.

    uv run --no-project python scripts/node_red_gas.py \
        exports/node-red/flows.json

The flow export is Node-Red's own configuration and therefore the
source of truth for its bus footprint. Every node whose type mentions
KNX is scanned, and every string field shaped like a group address
(M/C/S) counts as touched. That is deliberately schema-free: the KNX
palette keeps the address in different fields per node type, and a
false positive would have to be a group-address-shaped literal in an
unrelated field of a KNX node. One address per line, sorted.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_GA = re.compile(r"^\d{1,2}/\d/\d{1,3}$")


def flow_gas(path: Path) -> list[str]:
    nodes = json.loads(path.read_text(encoding="utf-8"))
    gas: set[str] = set()
    for node in nodes if isinstance(nodes, list) else []:
        if not isinstance(node, dict) or "knx" not in str(node.get("type", "")).lower():
            continue
        for value in node.values():
            if isinstance(value, str) and _GA.match(value.strip()):
                gas.add(value.strip())
    return sorted(gas, key=lambda ga: [int(part) for part in ga.split("/")])


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    gas = flow_gas(Path(sys.argv[1]))
    if not gas:
        raise SystemExit(
            "no group addresses found in any KNX node — is this a full flow export?"
        )
    print("\n".join(gas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
