"""Generate the Basalte logic inventory from a Studio export.

    uv run --no-project python scripts/basalte_create_inventory.py <export.bcfg> > inventory.md

Every logic block with its devices, thresholds and notifications — the set a
newly planned fault is checked against. The export's wire format is read by
`basalte_export.py`.
"""

from __future__ import annotations

import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_export import parse

UUID = re.compile(r"^\{?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}?$")


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
                    m["body"].strip()
                    for m in models
                    if m["name"].endswith("notification") and m.get("body", "").strip()
                ],
            }
        )
    return blocks, len(names)


def render(blocks: list[dict], named: int) -> str:
    pushing = sum(1 for b in blocks if b["notif"])
    messages = sum(len(b["notif"]) for b in blocks)
    summary = (
        f"**{len(blocks)} logic blocks**, **{pushing} of them notifying**, carrying "
        f"**{messages} distinct notifications** between them. {named} named objects in the export."
    )
    out = ["# Basalte logic: inventory", ""]
    out += [
        "Generated from the Studio export with `task basalte:create-inventory`.",
        "",
        summary,
        "",
        "## Notifications",
        "",
        "The existing set, against which every newly planned fault has to be checked.",
        "One row per notification — a block often carries several, one per room or device.",
        "",
        "| Block | Message | Thresholds | Devices |",
        "|---|---|---|---|",
    ]
    for b in sorted([x for x in blocks if x["notif"]], key=lambda x: str(x["name"])):
        refs = ", ".join(r for r in map(str, b["refs"]) if not r.startswith("?")) or "—"
        th = ", ".join(map(str, b["thresholds"])) or "—"
        for message in b["notif"]:
            txt = str(message).replace("\n", " ").replace("|", "/")
            out.append(f"| {b['name']} | {txt} | {th} | {refs} |")
    out += ["", "## All blocks", "", "| Block | Nodes | Node types |", "|---|---:|---|"]
    for b in sorted(blocks, key=lambda x: str(x["name"])):
        kinds = ", ".join(f"{k}×{v}" for k, v in sorted(b["kinds"].items()) if k != "comment")
        out.append(f"| {b['name']} | {b['n']} | {kinds[:150]} |")
    out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    export_path = Path(sys.argv[1])
    blocks, named = extract(export_path)
    sys.stdout.write(render(blocks, named))
    print(f"{len(blocks)} blocks from {export_path.name}, {named} named objects", file=sys.stderr)
