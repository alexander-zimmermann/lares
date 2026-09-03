"""Report the KNX addresses every Basalte thermostat is bound to.

    uv run --no-project --with pyyaml python scripts/basalte_thermostats.py \
        <export.bcfg> <ga-catalog.yaml> [faults.yaml]

Each room's thermostat carries the temperature the house treats as that
room's own — the value the app shows and the one the fault list measures
against the setpoint. The binding lives only in the Studio export, so it is
read from there rather than transcribed: give the fault file as the third
argument and the room→address mapping it declares is checked against what
Basalte actually reads.

The export is schema-less Protocol Buffers (see basalte_inventory.py for the
wire format). A thermostat item binds its addresses under field 20.5, one
sub-message per role — 1 temperature, 2 HVAC mode, 7 setpoint, 22 heating
active, 34 humidity — each holding a write slot (1) and a status slot (2)
with the address as a varint plus a hand-typed label. The labels carry
typos ("Esszimer", "Temperartur"), so the address is the key and the ETS
catalog decides which room it belongs to.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_inventory import parse

ROLES = {1: "temperature", 2: "hvac", 7: "setpoint", 22: "active", 34: "humidity"}
ROOM = re.compile(r"^[^.]+\.((?:EG|OG|KG|DG)\.[^.]+)\.")


def ga_text(value: int) -> str:
    return f"{value >> 11}/{(value >> 8) & 7}/{value & 255}"


def field_of(node: list, number: int):
    for num, _kind, value in node:
        if num == number:
            return value
    return None


def slots(role: list) -> dict[int, str]:
    """{slot: group address} for the write (1) and status (2) slots."""
    found: dict[int, str] = {}
    for slot, kind, value in role:
        if kind != "msg":
            continue
        address = field_of(value, 1)
        if isinstance(address, int) and address:
            found[slot] = ga_text(address)
    return found


def thermostats(export: Path) -> list[dict[str, dict[int, str]]]:
    """Every item binding both a setpoint and a temperature."""
    found = []
    for field, kind, value in parse(export.read_bytes()):
        if field != 6 or kind != "msg":
            continue
        body = field_of(value, 20)
        roles = field_of(body, 5) if isinstance(body, list) else None
        if not isinstance(roles, list):
            continue
        bound = {
            ROLES[num]: slots(role)
            for num, k, role in roles
            if k == "msg" and num in ROLES and slots(role)
        }
        if "setpoint" in bound and "temperature" in bound:
            found.append(bound)
    return found


def declared_values(faults_path: Path, catalog: dict[str, str]) -> dict[str, str] | None:
    """{room: group address} the fault list's deviation fault declares as
    its value channel, resolved against the catalog. Every room names its
    own — there is no shared fallback to fall back to."""
    faults = yaml.safe_load(faults_path.read_text(encoding="utf-8"))
    fault = next(
        (f for f in faults.get("faults", []) if f.get("kind") == "deviation"), None
    )
    if fault is None:
        return None
    by_name = {name: ga for ga, name in catalog.items()}
    declared: dict[str, str] = {}
    for room, rule in fault["rooms"].items():
        pattern = rule["value"]
        regex = ".*".join(re.escape(p).replace("_", ".") for p in pattern.split("%"))
        hits = [
            ga
            for name, ga in by_name.items()
            if re.fullmatch(regex, name) and f".{room}." in name
        ]
        declared[room] = hits[0] if len(hits) == 1 else f"<{len(hits)} matches>"
    return declared


def main() -> int:
    export, catalog_path = Path(sys.argv[1]), Path(sys.argv[2])
    faults_path = Path(sys.argv[3]) if len(sys.argv) > 3 else None

    raw = yaml.safe_load(catalog_path.read_text(encoding="utf-8"))
    catalog = {
        str(ga): meta["name"]
        for ga, meta in raw.items()
        if isinstance(meta, dict) and "name" in meta
    }

    rows = []
    for bound in thermostats(export):
        temperature = bound["temperature"].get(2)
        setpoint = bound["setpoint"].get(2)
        name = catalog.get(temperature or "")
        room = ROOM.match(name).group(1) if name and ROOM.match(name) else None
        rows.append((room, temperature, setpoint, name))
    rows.sort(key=lambda r: str(r[0]))

    print(f"{len(rows)} thermostats in {export.name}\n")
    print(f"{'room':26s} {'temperature':10s} {'setpoint':10s} channel")
    problems: list[str] = []
    for room, temperature, setpoint, name in rows:
        print(f"{room!s:26s} {temperature!s:10s} {setpoint!s:10s} {name}")
        if name is None:
            problems.append(f"{temperature}: temperature address is not in the catalog")
            continue
        setpoint_name = catalog.get(setpoint or "")
        setpoint_room = (
            ROOM.match(setpoint_name).group(1)
            if setpoint_name and ROOM.match(setpoint_name)
            else None
        )
        if setpoint_room != room:
            problems.append(
                f"{room}: reads setpoint {setpoint} — "
                + (f"{setpoint_room}'s address" if setpoint_room else "not in the catalog")
            )

    if faults_path is not None:
        declared = declared_values(faults_path, catalog)
        bound_by_room = {room: temperature for room, temperature, _s, _n in rows}
        print(f"\nagainst {faults_path.name}:")
        for room, address in sorted((declared or {}).items()):
            actual = bound_by_room.get(room)
            mark = "ok" if address == actual else f"declares {address}, thermostat reads {actual}"
            print(f"   {room:26s} {mark}")
            if address != actual:
                problems.append(f"{room}: fault list {mark}")
        for room in sorted(set(bound_by_room) - set(declared or {})):
            print(f"   {room:26s} thermostat exists, not declared in the fault list")

    if problems:
        print("\nproblems:")
        for problem in problems:
            print(f"   {problem}")
        return 1
    print("\nno problems")
    return 0


if __name__ == "__main__":
    sys.exit(main())
