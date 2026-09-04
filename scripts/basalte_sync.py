"""Check whether Basalte still agrees with ETS about the group addresses.

    uv run --no-project --with pyyaml python scripts/basalte_sync.py \
        <export.bcfg> <ets-catalog.yaml>

The ETS side is the project itself, extracted for this run — `task
basalte:sync` does that first. Comparing against the committed
`ga-catalog.yaml` would answer a different question: whether Basalte
matches what the repo last wrote down, which is a snapshot and can be
older than ETS.

Basalte holds the bus in two layers. One is the imported ETS project,
which a re-import refreshes wholesale. The other is every device and
logic block, and each of those stores a *copy* of the address name it was
wired with — so a rename or renumbering in ETS afterwards leaves the copy
behind. The copy is only a label, but where the address moved rather than
the name, the binding itself points at the wrong place and nothing on the
bus says so.

Three findings, by how much they cost:

* **stale binding** — the datapoint the object was wired to lives under a
  different address now. Whether the address it still holds exists decides
  only how loudly it fails: gone means silence, re-used means a plausible
  value that measures something else. This is the class that matters.
* **stale label** — the address is right, the name beside it is what ETS
  called it once. Cosmetic; a re-assignment in Studio refreshes it.
* **unknown** — neither the address nor the name is in ETS. Datapoints
  Basalte uses that were never created live here, so this needs deciding
  once rather than reading every run.

Only a stale binding fails the run.

The export is schema-less Protocol Buffers; `basalte_inventory.py`
documents the wire format. An address binding is any message carrying the
address as a varint in field 1 and its name in field 2.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_inventory import parse

# The import layer: the whole ETS project as Basalte read it, one
# top-level entry. Everything else that binds addresses is a device or a
# logic block — the layers whose copies go stale.
_IMPORT_FIELD = 19

# A name Basalte would have taken from ETS: starts like a function prefix
# and carries no markup. Keeps the scan off the many other strings in the
# export that happen to sit beside a number.
_NAME = re.compile(r"^[A-ZÄÖÜ][\w.\-/äöüßÄÖÜ ]+$")


def group_address(value: int) -> str:
    return f"{value >> 11}/{(value >> 8) & 7}/{value & 255}"


def bindings(node: list, found: list[tuple[str, str]]) -> None:
    """Every (address, name) pair under `node`, depth first."""
    address = name = None
    for field, kind, value in node:
        if field == 1 and kind == "v":
            address = value
        elif field == 2 and kind == "str":
            name = value
        elif kind == "msg":
            bindings(value, found)
    # Below 2048 is main group 0, which this house does not use for
    # bindings; above 65535 is not a group address at all.
    if address and name and 2048 <= address < 65536 and _NAME.match(name):
        found.append((group_address(address), name))


def layers(export: Path) -> tuple[list[tuple[str, str]], list[tuple[str, str]]]:
    """The import layer's bindings and the device/logic layers' bindings."""
    imported: list[tuple[str, str]] = []
    wired: list[tuple[str, str]] = []
    for field, kind, value in parse(export.read_bytes()):
        if kind != "msg":
            continue
        bindings(value, imported if field == _IMPORT_FIELD else wired)
    return imported, wired


def ets_of(path: Path) -> dict[str, str]:
    """{address: name} as ETS defines it, from a freshly extracted catalog."""
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    return {
        str(ga): entry["name"]
        for ga, entry in raw.items()
        if isinstance(entry, dict) and "name" in entry
    }


def main() -> int:
    export, ets_path = Path(sys.argv[1]), Path(sys.argv[2])
    catalog = ets_of(ets_path)
    by_name = {name: ga for ga, name in catalog.items()}
    imported, wired = layers(export)

    print(f"ETS project: {len(catalog)} addresses")
    drifted = {(ga, name) for ga, name in imported if catalog.get(ga) != name}
    print(
        f"{export.name}: {len(set(imported))} imported bindings, "
        f"{len(drifted)} of them off ETS"
    )
    # A handful of drifted imports is ETS' own noise; a fifth of them means
    # the project was re-exported and Studio has not seen it yet. Then every
    # wired copy is old by construction and listing them says nothing.
    import_behind = len(drifted) * 5 > len(set(imported))
    if import_behind:
        print("  the ETS import is behind — re-import in Studio, then re-run")

    stale_binding: list[tuple[str, str, str, str | None]] = []
    stale_label: list[tuple[str, str, str]] = []
    unknown: list[tuple[str, str]] = []
    for ga, name in sorted(set(wired)):
        elsewhere = by_name.get(name)
        if elsewhere is not None and elsewhere != ga:
            # The datapoint this object was wired to lives somewhere else
            # now. Whether the address it holds still exists decides how
            # loudly it fails, not whether it is wrong: an address that was
            # re-used reads a plausible value that means something else.
            stale_binding.append((ga, elsewhere, name, catalog.get(ga)))
        elif ga in catalog:
            if catalog[ga] != name:
                stale_label.append((ga, catalog[ga], name))
        else:
            unknown.append((ga, name))

    print(f"\n=== {len(stale_binding)} stale bindings — the address moved in ETS")
    for ga, correct, name, occupant in sorted(stale_binding, key=lambda b: b[3] is None):
        print(f"  {ga:9s} -> {correct:9s}  {name}")
        if occupant is not None:
            print(f"  {'':9s}    {ga} is now {occupant}")

    print(f"\n=== {len(stale_label)} stale labels — right address, old name")
    if import_behind:
        print("  not listed: they follow from the pending re-import, not from wiring")
    else:
        for ga, ets, basalte in stale_label:
            print(f"  {ga:9s} ETS      {ets}")
            print(f"  {'':9s} Basalte  {basalte}")

    print(f"\n=== {len(unknown)} unknown to ETS")
    for prefix, count in Counter(name.split(".")[0] for _ga, name in unknown).most_common():
        print(f"  {prefix:22s} {count}")
    for ga, name in unknown:
        print(f"    {ga:9s} {name}")

    if stale_binding:
        print(f"\n{len(stale_binding)} stale bindings — re-assign them in Studio")
        return 1
    print("\nno stale binding")
    return 0


if __name__ == "__main__":
    sys.exit(main())
