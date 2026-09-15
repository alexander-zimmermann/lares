"""Read a Basalte Studio export (.bcfg) — shared by the basalte and knx scripts.

Not a task: `basalte_create_inventory.py`, `basalte_validate_bindings.py` and
`knx_extract_footprints.py` import from here.

The export is Protocol Buffers with no schema shipped, so the wire format is
read generically. Decoded so far:

* field 100 is one logic block: field 1 its UUID, field 2 its name, field 3 the
  generated Lua, field 5 the node graph as JSON
* nodes are named ``be::basalte::nodemodel::<type>`` — ``setnumber`` carries
  ``triggerValue``, ``compare`` a ``compareMode``, ``chrono`` a ``period``,
  ``notification`` the ``body``; device nodes reference an ``itemUuid``
* device UUIDs resolve against the named objects elsewhere in the export
* field 19 is the import layer: the whole ETS project as Basalte read it, one
  top-level entry. Everything else that binds addresses is a device or a
  logic block; an address binding is any message carrying the address as a
  varint in field 1 and its name in field 2

Basalte holds the bus in two layers. The import layer a re-import refreshes
wholesale. Every device and logic block stores a *copy* of the address name
it was wired with — so a rename or renumbering in ETS afterwards leaves the
copy behind; `layers()` separates the two.
"""

from __future__ import annotations

import re
from pathlib import Path

_IMPORT_FIELD = 19

# A name Basalte would have taken from ETS: Funktion.Gerät.Datenpunkt, so a
# capitalised prefix, at least one dot, no markup. Keeps the scan off the
# many other strings in the export that happen to sit beside a number — the
# media remotes' key names ("VOLUME UP", "DIGIT 0") share the low range
# with main group 0 and only the dot tells them apart. ETS names also carry
# "+" (Lademodus-PV+Min) and, for some umlauts, a combining diaeresis
# instead of the precomposed letter — both are names, not markup.
_NAME = re.compile(r"^[A-ZÄÖÜ][\w\-/+äöüßÄÖÜ̈ ]*\.[\w.\-/+äöüßÄÖÜ̈ ]+$")


# --- Schema-less protobuf ----------------------------------------------------

def read_varint(buf: bytes, i: int) -> tuple[int, int]:
    result = shift = 0
    while i < len(buf):
        byte = buf[i]
        i += 1
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result, i
        shift += 7
        if shift > 70:
            raise ValueError("varint too long")
    raise ValueError("truncated varint")


def as_text(raw: bytes) -> str | None:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        return None
    return text if all(c in "\n\t" or 0x20 <= ord(c) < 0x10000 for c in text) else None


def parse(buf: bytes, depth: int = 0) -> list[tuple[int, str, object]]:
    """[(field_number, kind, value)] with kind in v/f32/f64/msg/str/bytes."""
    out: list[tuple[int, str, object]] = []
    i = 0
    while i < len(buf):
        tag, i = read_varint(buf, i)
        field, wire = tag >> 3, tag & 7
        if field == 0:
            raise ValueError("field number 0")
        if wire == 0:
            value, i = read_varint(buf, i)
            out.append((field, "v", value))
        elif wire in (1, 5):
            width = 8 if wire == 1 else 4
            if i + width > len(buf):
                raise ValueError("truncated fixed field")
            out.append((field, "f64" if wire == 1 else "f32", buf[i : i + width]))
            i += width
        elif wire == 2:
            length, i = read_varint(buf, i)
            if i + length > len(buf):
                raise ValueError("truncated bytes")
            payload, i = buf[i : i + length], i + length
            nested = None
            if payload and depth < 40:
                try:
                    nested = parse(payload, depth + 1)
                except (ValueError, IndexError):
                    nested = None
            text = as_text(payload)
            if nested is not None and (text is None or len(nested) > 1):
                out.append((field, "msg", nested))
            elif text is not None:
                out.append((field, "str", text))
            else:
                out.append((field, "bytes", payload))
        else:
            raise ValueError(f"unsupported wire type {wire}")
    return out


# --- Address bindings --------------------------------------------------------

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
    # 0/0/0 is the broadcast address; above 65535 is not a group address.
    if address and name and address < 65536 and _NAME.match(name):
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
