"""Extract a generated device's footprint from its own configuration.

    uv run --no-project --with pyyaml python scripts/knx_extract_footprints.py \\
        bridge   <ga-mappings-dir> <consumers-dir>
        basalte  <export.bcfg>
        nodered  <flows.json>
        telenot  <compasx-export.csv>

A footprint is the set of group addresses a generated device actually
touches, each with its direction, as its configuration defines it — never
what ETS happens to link to it (CONTEXT.md). One `<address> <direction>`
per line, sorted; the direction is `transmit` (the device sends), `write`
(the device acts on writes) or `both`. The bridge's addresses come as NATS
subjects (knx.M.C.S), the others as M/C/S. Only the extractor knows the
configuration, so only it decides the direction.

* `bridge` — the writer targets of every *.yaml in the GA-mappings directory
  (`transmit`) and the KNX filter subjects of the *_from_knx.yaml Consumer
  manifests (`write`: a write on the bus reaches an appliance through the
  bridge, so the catalog's `writable` can answer from the project alone).
  Deriving it from the project instead would enshrine whatever accumulated
  on the placeholder.
* `basalte` — the addresses the Studio export's device and logic layers bind
  (the import layer mirrors the whole ETS project and does not count); a
  visualisation displays and sends, so `both`. Bindings ETS no longer knows
  print like any other and fail later, in the generator, where they are
  reported per address.
* `nodered` — every group-address-shaped string in every node whose type
  mentions KNX, `both`. Deliberately schema-free: the KNX palette keeps the
  address in different fields per node type; a false positive would have to
  be a group-address-shaped literal in an unrelated field of a KNX node.
* `telenot` — the compasX export of the KNX interface: `KNX_Status` is what
  the panel sends (`transmit`), `KNX_Switch` what it acts on (`write`).
"""

from __future__ import annotations

import csv
import json
import re
import sys
from collections.abc import Callable, Iterable
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_export import layers

_GA = re.compile(r"^\d{1,2}/\d/\d{1,3}$")
# compasX writes a.b.c and marks "no address" two ways.
_COMPASX_GA = re.compile(r"^\d{1,2}\.\d\.\d{1,3}$")
_COMPASX_NONE = {"0.0.0", "--"}
_COMPASX_HEADER = ["ID", "Name", "KNX_Status", "KNX_Switch"]


def _by_address(ga: str) -> list[int]:
    return [int(part) for part in ga.split("/")]


def _by_subject(subject: str) -> list[int]:
    return [int(part) for part in subject.split(".")[1:]]


def _directed(sends: Iterable[str], acts: Iterable[str]) -> dict[str, str]:
    """{address -> direction} from what the device sends and what it acts on."""
    sends, acts = set(sends), set(acts)
    directions = {address: "transmit" for address in sends - acts}
    directions |= {address: "write" for address in acts - sends}
    directions |= {address: "both" for address in sends & acts}
    return directions


def consumed_subjects(consumers_dir: Path) -> set[str]:
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
    return subjects


def bridge_footprint(mappings_dir: Path, consumers_dir: Path) -> dict[str, str]:
    targets: set[str] = set()
    for file in sorted(mappings_dir.glob("*.yaml")):
        rules = yaml.safe_load(file.read_text(encoding="utf-8"))
        targets.update(
            "knx." + str(mapping["ga"]).replace("/", ".") for mapping in rules["mappings"]
        )
    return _directed(targets, consumed_subjects(consumers_dir))


def basalte_footprint(export: Path) -> dict[str, str]:
    _, wired = layers(export)
    gas = {ga for ga, _ in wired}
    if not gas:
        raise SystemExit("no bindings found in the export")
    return _directed(gas, gas)


def nodered_footprint(flows: Path) -> dict[str, str]:
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
    return _directed(gas, gas)


def telenot_footprint(export: Path) -> dict[str, str]:
    # A title line and a blank line precede the column header.
    lines = export.read_text(encoding="cp1252").splitlines()
    try:
        start = lines.index(";".join(_COMPASX_HEADER))
    except ValueError:
        raise SystemExit(f"{export.name}: no {';'.join(_COMPASX_HEADER)} header line") from None
    status: set[str] = set()
    switch: set[str] = set()
    for number, row in enumerate(csv.reader(lines[start + 1 :], delimiter=";"), start=start + 2):
        if not any(row):
            continue
        if len(row) < len(_COMPASX_HEADER):
            raise SystemExit(f"{export.name}:{number}: expected {len(_COMPASX_HEADER)} columns")
        for column, into in ((2, status), (3, switch)):
            value = row[column].strip()
            if value in _COMPASX_NONE:
                continue
            if not _COMPASX_GA.match(value):
                raise SystemExit(f"{export.name}:{number}: {value!r} is not a group address")
            into.add(value.replace(".", "/"))
    if not status and not switch:
        raise SystemExit(f"{export.name}: no group addresses in KNX_Status or KNX_Switch")
    return _directed(status, switch)


# device → (number of path arguments, extractor, sort key)
DEVICES: dict[str, tuple[int, Callable[..., dict[str, str]], Callable[[str], list[int]]]] = {
    "bridge": (2, bridge_footprint, _by_subject),
    "basalte": (1, basalte_footprint, _by_address),
    "nodered": (1, nodered_footprint, _by_address),
    "telenot": (1, telenot_footprint, _by_address),
}


def main() -> int:
    device = sys.argv[1] if len(sys.argv) > 1 else None
    if device not in DEVICES or len(sys.argv) != 2 + DEVICES[device][0]:
        print(__doc__, file=sys.stderr)
        return 2
    _, extract, key = DEVICES[device]
    footprint = extract(*map(Path, sys.argv[2:]))
    print("\n".join(f"{address} {footprint[address]}" for address in sorted(footprint, key=key)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
