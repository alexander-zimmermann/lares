"""List the KNX subjects that NATS consumers act on.

    uv run --no-project --with pyyaml python scripts/knx_consumed_gas.py \
        kubernetes/applications/nats/base/consumers

Scans the *_from_knx.yaml Consumer manifests and prints every KNX
filter subject, one per line, sorted by group address. These are the
addresses where a write on the bus reaches an appliance through the
bridge — the set the ETS bridge device carries with the Write flag, so
the catalog's `writable` can answer from the project alone.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml


def consumed_subjects(consumers_dir: Path) -> list[str]:
    subjects: set[str] = set()
    for path in sorted(consumers_dir.glob("*_from_knx.yaml")):
        for doc in yaml.safe_load_all(path.read_text(encoding="utf-8")):
            if not isinstance(doc, dict):
                continue
            spec = doc.get("spec")
            if not isinstance(spec, dict):
                continue
            single = spec.get("filterSubject")
            many = spec.get("filterSubjects")
            for subject in ([single] if single else []) + (many if isinstance(many, list) else []):
                subject = str(subject)
                if not subject.startswith("knx."):
                    raise SystemExit(f"{path.name}: unexpected filter subject {subject!r}")
                subjects.add(subject)
    return sorted(subjects, key=lambda s: [int(part) for part in s.split(".")[1:]])


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    consumers_dir = Path(sys.argv[1])
    subjects = consumed_subjects(consumers_dir)
    if not subjects:
        raise SystemExit(f"no *_from_knx.yaml consumers found in {consumers_dir}")
    print("\n".join(subjects))
    return 0


if __name__ == "__main__":
    sys.exit(main())
