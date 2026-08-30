"""Generate the Basalte logic inventory from a Studio export.

    uv run --no-project python scripts/basalte_inventory.py <export.bcfg> <output.md>

The export is Protocol Buffers with no schema shipped, so the wire format is
read generically. Decoded so far:

* field 100 is one logic block: field 1 its UUID, field 2 its name, field 3 the
  generated Lua, field 5 the node graph as JSON
* nodes are named ``be::basalte::nodemodel::<type>`` — ``setnumber`` carries
  ``triggerValue``, ``compare`` a ``compareMode``, ``chrono`` a ``period``,
  ``notification`` the ``body``; device nodes reference an ``itemUuid``
* device UUIDs resolve against the named objects elsewhere in the export

"""

from __future__ import annotations

import collections
import json
import re
import sys
from pathlib import Path

UUID = re.compile(r"^\{?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}?$")


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


# --- Basalte extraction ------------------------------------------------------

def build_name_index(node, names: dict[str, str]) -> None:
    """Any message carrying a UUID in field 1 and a name in field 2."""
    fields: dict[int, str] = {}
    for field, kind, value in node:
        if kind == "str" and field in (1, 2):
            fields.setdefault(field, value)
        elif kind == "msg":
            build_name_index(value, names)
    uuid, name = fields.get(1), fields.get(2)
    if uuid and name and UUID.match(uuid) and not UUID.match(name):
        names.setdefault(uuid.strip("{}"), name)


def field_of(block, number):
    for num, _kind, value in block:
        if num == number:
            return value
    return None


def extract(export: Path) -> list[dict]:
    tree = parse(export.read_bytes())
    names: dict[str, str] = {}
    build_name_index(tree, names)

    blocks = []
    for _num, kind, value in tree:
        if kind != "msg":
            continue
        graph = field_of(value, 5)
        if not isinstance(graph, str) or '"nodes"' not in graph:
            continue
        models = [node["model"] for node in json.loads(graph)["nodes"]]
        refs = [
            names.get(m["itemUuid"].strip("{}"), "?" + m["itemUuid"].strip("{}")[:8])
            for m in models
            if "itemUuid" in m
        ]
        name = field_of(value, 2)
        blocks.append(
            {
                "name": name if isinstance(name, str) else "(unnamed)",
                "n": len(models),
                "kinds": dict(collections.Counter(m["name"].split("::")[-1] for m in models)),
                "refs": sorted(set(refs)),
                "thresholds": sorted({m["triggerValue"] for m in models if "triggerValue" in m}, key=str),
                "notif": [
                    {
                        "body": m["body"].strip(),
                        "sink": m.get("sink", "?"),
                        "subject": m.get("subject", ""),
                    }
                    for m in models
                    if m["name"].endswith("notification") and m.get("body", "").strip()
                ],
            }
        )
    return blocks, len(names)


def render(blocks: list[dict], named: int) -> str:
    pushing = sum(1 for b in blocks if b["notif"])
    messages = sum(len(b["notif"]) for b in blocks)
    app = sum(1 for b in blocks for n in b["notif"] if n["sink"] == "app")
    mail = sum(1 for b in blocks for n in b["notif"] if n["sink"] == "email")
    summary = (
        f"**{len(blocks)} logic blocks**, **{pushing} of them notifying**, carrying "
        f"**{messages} distinct notifications** between them — {app} to the app, {mail} by e-mail. "
        f"{named} named objects in the export."
    )
    out = ["# Basalte logic: inventory", ""]
    out += [
        "Generated from the Studio export with `task basalte:inventory` — **do not hand-edit**.",
        "Regenerate after every change in Basalte and read the diff.",
        "",
        "The export itself is not in the repo: 14 MB of binary, and it carries at least one",
        "value that looks like an access token. See `docs/basalte/README.md` for where it goes.",
        "",
        summary,
        "",
        "## Notifications",
        "",
        "The existing set, against which every newly planned fault has to be checked.",
        "One row per notification — a block often carries several, one per room or device.",
        "",
        "| Block | Channel | Message | Thresholds | Devices |",
        "|---|---|---|---|---|",
    ]
    for b in sorted([x for x in blocks if x["notif"]], key=lambda x: str(x["name"])):
        refs = ", ".join(r for r in map(str, b["refs"]) if not r.startswith("?")) or "—"
        th = ", ".join(map(str, b["thresholds"])) or "—"
        for message in b["notif"]:
            txt = str(message["body"]).replace("\n", " ").replace("|", "/")
            out.append(f"| {b['name']} | {message['sink']} | {txt} | {th} | {refs} |")
    out += ["", "## All blocks", "", "| Block | Nodes | Node types |", "|---|---:|---|"]
    for b in sorted(blocks, key=lambda x: str(x["name"])):
        kinds = ", ".join(f"{k}×{v}" for k, v in sorted(b["kinds"].items()) if k != "comment")
        out.append(f"| {b['name']} | {b['n']} | {kinds[:150]} |")
    out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    export_path = Path(sys.argv[1])
    blocks, named = extract(export_path)
    Path(sys.argv[2]).write_text(render(blocks, named), encoding="utf-8")
    print(f"{len(blocks)} blocks from {export_path.name}, {named} named objects")
