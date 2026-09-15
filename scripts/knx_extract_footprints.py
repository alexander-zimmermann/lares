"""Extract a software bus participant's footprint from its own configuration.

    uv run --no-project --with pyyaml python scripts/knx_extract_footprints.py \\
        consumed <consumers-dir>                  # the addresses NATS consumers act on
        bridge   <ga-mappings-dir> <consumers-dir>
        basalte  <export.bcfg>
        nodered  <flows.json>

A footprint is the set of group addresses a participant actually touches,
as its configuration defines it — never what ETS happens to link to it
(CONTEXT.md). One address per line, sorted; the bridge's two lists come as
NATS subjects (knx.M.C.S), the others as M/C/S.

* `consumed` — the KNX filter subjects of the *_from_knx.yaml Consumer
  manifests: where a write on the bus reaches an appliance through the
  bridge. The ETS bridge device carries these with the Write flag, so the
  catalog's `writable` can answer from the project alone.
* `bridge` — the writer targets of every *.yaml in the GA-mappings directory
  plus the consumed subjects: what the generated ETS bridge device must
  carry. Deriving it from the project instead would enshrine whatever
  accumulated on the placeholder.
* `basalte` — the addresses the Studio export's device and logic layers bind
  (the import layer mirrors the whole ETS project and does not count).
  Bindings ETS no longer knows print like any other and fail later, in the
  generator, where they are reported per address.
* `nodered` — every group-address-shaped string in every node whose type
  mentions KNX. Deliberately schema-free: the KNX palette keeps the address
  in different fields per node type; a false positive would have to be a
  group-address-shaped literal in an unrelated field of a KNX node.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_export import layers

_GA = re.compile(r"^\d{1,2}/\d/\d{1,3}$")


def _by_address(ga: str) -> list[int]:
    return [int(part) for part in ga.split("/")]


def _by_subject(subject: str) -> list[int]:
    return [int(part) for part in subject.split(".")[1:]]


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
    if not subjects:
        raise SystemExit(f"no *_from_knx.yaml consumers found in {consumers_dir}")
    return sorted(subjects, key=_by_subject)


def bridge_subjects(mappings_dir: Path, consumers_dir: Path) -> list[str]:
    subjects: set[str] = set()
    for file in sorted(mappings_dir.glob("*.yaml")):
        rules = yaml.safe_load(file.read_text(encoding="utf-8"))
        subjects.update(
            "knx." + str(mapping["ga"]).replace("/", ".") for mapping in rules["mappings"]
        )
    subjects.update(consumed_subjects(consumers_dir))
    return sorted(subjects, key=_by_subject)


def basalte_gas(export: Path) -> list[str]:
    _, wired = layers(export)
    gas = sorted({ga for ga, _ in wired}, key=_by_address)
    if not gas:
        raise SystemExit("no bindings found in the export")
    return gas


def nodered_gas(flows: Path) -> list[str]:
    nodes = json.loads(flows.read_text(encoding="utf-8"))
    gas: set[str] = set()
    for node in nodes if isinstance(nodes, list) else []:
        if not isinstance(node, dict) or "knx" not in str(node.get("type", "")).lower():
            continue
        for value in node.values():
            if isinstance(value, str) and _GA.match(value.strip()):
                gas.add(value.strip())
    if not gas:
        raise SystemExit("no group addresses found in any KNX node — is this a full flow export?")
    return sorted(gas, key=_by_address)


# participant → (number of path arguments, extractor)
PARTICIPANTS = {
    "consumed": (1, consumed_subjects),
    "bridge": (2, bridge_subjects),
    "basalte": (1, basalte_gas),
    "nodered": (1, nodered_gas),
}


def main() -> int:
    participant = sys.argv[1] if len(sys.argv) > 1 else None
    if participant not in PARTICIPANTS or len(sys.argv) != 2 + PARTICIPANTS[participant][0]:
        print(__doc__, file=sys.stderr)
        return 2
    _, extract = PARTICIPANTS[participant]
    print("\n".join(extract(*map(Path, sys.argv[2:]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
