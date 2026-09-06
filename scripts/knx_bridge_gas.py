"""List every group address the KNX-NATS bridge touches on the bus.

    uv run --no-project --with pyyaml python scripts/knx_bridge_gas.py \
        kubernetes/applications/knx-nats-bridge/base/config/writer-rules.yaml \
        kubernetes/applications/nats/base/consumers

The bridge's bus footprint is defined here, not in ETS: the writer
rules name the addresses it sends to, the *_from_knx consumers the
addresses whose writes it acts on. The union, printed one subject per
line, is what the generated ETS bridge device must carry — deriving it
from the project instead would enshrine whatever accumulated on the
placeholder.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from knx_consumed_gas import consumed_subjects


def bridge_subjects(writer_rules: Path, consumers_dir: Path) -> list[str]:
    rules = yaml.safe_load(writer_rules.read_text(encoding="utf-8"))
    subjects = {
        "knx." + str(mapping["ga"]).replace("/", ".") for mapping in rules["mappings"]
    }
    subjects.update(consumed_subjects(consumers_dir))
    return sorted(subjects, key=lambda s: [int(part) for part in s.split(".")[1:]])


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    print("\n".join(bridge_subjects(Path(sys.argv[1]), Path(sys.argv[2]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
