"""Check whether Basalte still agrees with ETS about the group addresses.

    uv run --no-project --with pyyaml python scripts/basalte_validate_bindings.py \
        <export.bcfg> <ga-catalog.yaml>

The ETS side is the catalog, which is a snapshot of the project: an
address created in ETS since the last `task knx:create-ga-catalog` would
look like one Basalte invented. `task basalte:validate-bindings` keeps that
from happening by refusing to run while the .knxproj is newer — which is
why this stays two plain files to read instead of an extraction with a
project password.

Basalte holds the bus in two layers (`basalte_export.layers`): the imported
ETS project, and every device and logic block with a *copy* of the address
name it was wired with. The copy is only a label, but where the address
moved rather than the name, the binding itself points at the wrong place
and nothing on the bus says so.

Three findings, by how much they cost:

* **stale binding** — the datapoint the object was wired to lives under a
  different address now. Whether the address it still holds exists decides
  only how loudly it fails: gone means silence, re-used means a plausible
  value that measures something else. This is the class that matters.
* **stale label** — the address is right, the name beside it is what ETS
  called it once. Cosmetic; a re-assignment in Studio refreshes it.
* **not in the catalog** — neither the address nor the name is in the
  catalog. Two causes, which the catalog cannot tell apart: the address
  was created in ETS without a datapoint type (the catalog only lists
  typed addresses — set the DPT and it appears), or it was never created
  in ETS at all. Datapoints Basalte uses that fall in here need deciding
  once rather than reading every run.

Only a stale binding fails the run.
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_export import layers


def catalog_of(path: Path) -> dict[str, str]:
    """{address: name} as ETS defines it, per the catalog."""
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    return {
        str(ga): entry["name"]
        for ga, entry in raw.items()
        if isinstance(entry, dict) and "name" in entry
    }


def main() -> int:
    export, catalog_path = Path(sys.argv[1]), Path(sys.argv[2])
    catalog = catalog_of(catalog_path)
    by_name = {name: ga for ga, name in catalog.items()}
    imported, wired = layers(export)

    print(f"{catalog_path.name}: {len(catalog)} addresses")
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

    print(
        f"\n=== {len(unknown)} not in the catalog — in ETS without a DPT, or not in ETS at all"
    )
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
