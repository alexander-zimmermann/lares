"""List the group addresses Basalte actually binds.

    uv run --no-project --with pyyaml python scripts/basalte_gas.py \
        exports/basalte/Steinroth.bcfg

The Studio export holds the bus twice: the import layer mirrors the
whole ETS project, while the device and logic layers bind only the
datapoints actually wired in Studio. The latter is Basalte's true
footprint — the set its ETS device must carry — printed one address
per line, sorted. Addresses the export binds but ETS no longer knows
(stale bindings) print like any other and fail later, in the generator,
where they are reported per address.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_sync import layers


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    _, wired = layers(Path(sys.argv[1]))
    gas = sorted({ga for ga, _ in wired}, key=lambda g: [int(part) for part in g.split("/")])
    if not gas:
        raise SystemExit("no bindings found in the export")
    print("\n".join(gas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
