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
from datetime import datetime
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


TIER_RE = re.compile(r"^(Info|Warnung|Kritisch|Ende)\s*:\s*(.+)$", re.DOTALL)
TIER_ORDER = ("Info", "Warnung", "Kritisch", "Ende")


def group_messages(notif: list[str]) -> list[tuple[str, list[str]]]:
    """One row per sentence, with every tier it is sent as — a receiver
    carries the same sentence as Info, Warnung and Kritisch mail."""
    tiers: dict[str, set[str]] = {}
    order: list[str] = []
    for message in notif:
        txt = " ".join(str(message).split()).replace("|", "/")
        m = TIER_RE.match(txt)
        tier, sentence = (m.group(1), m.group(2)) if m else ("", txt)
        if sentence not in tiers:
            tiers[sentence] = set()
            order.append(sentence)
        if tier:
            tiers[sentence].add(tier)
    return [(s, [t for t in TIER_ORDER if t in tiers[s]]) for s in order]


def merged(blocks: list[dict]) -> list[tuple[str, list[dict]]]:
    """Blocks that share a name (one per device: 21× Standby) as one group,
    sorted by name."""
    groups: dict[str, list[dict]] = collections.defaultdict(list)
    for b in blocks:
        groups[str(b["name"])].append(b)
    return sorted(groups.items())


def render(blocks: list[dict], named: int, export: Path) -> str:
    notifying = [b for b in blocks if b["notif"]]
    messages = sum(len(b["notif"]) for b in blocks)
    sentences = sum(len(group_messages([m for b in g for m in b["notif"]])) for _, g in merged(notifying))
    exported = datetime.fromtimestamp(export.stat().st_mtime).strftime("%d.%m.%Y %H:%M")
    today = datetime.now().strftime("%d.%m.%Y")
    out = [
        "# Basalte-Logik: Inventar",
        "",
        (
            f"Generiert am {today} aus `{export.name}` (Export vom {exported}) mit "
            "`task basalte:create-inventory`. Erzeugte Seite: nach dem nächsten Export neu "
            "schreiben, nicht von Hand ändern."
        ),
        "",
        (
            f"**{len(blocks)} Logikblöcke**, davon **{len(notifying)} mit Meldungen**: "
            f"{messages} Meldungstexte, {sentences} verschiedene Sätze. {named} benannte Objekte im Export."
        ),
        "",
        "## Meldungen",
        "",
        (
            "Der Bestand, gegen den jeder neu geplante Fehler geprüft wird. Je Block eine Tabelle, "
            "eine Zeile pro Satz; die Stufen daneben sagen, als was er verschickt wird."
        ),
        "",
    ]
    for name, group in merged(notifying):
        count = f" ({len(group)} Blöcke)" if len(group) > 1 else ""
        out += [f"### {name}{count}", ""]
        refs = sorted({r for b in group for r in map(str, b["refs"]) if not r.startswith("?")})
        th = sorted({str(t) for b in group for t in b["thresholds"]})
        if th:
            out.append(f"Schwellen: {', '.join(th)}  ")
        if refs:
            out.append(f"Geräte: {', '.join(refs)}  ")
        if th or refs:
            out.append("")
        out += ["| Meldung | Stufen |", "|---|---|"]
        for sentence, tiers in group_messages([m for b in group for m in b["notif"]]):
            out.append(f"| {sentence} | {' · '.join(tiers) or '—'} |")
        out.append("")
    out += ["## Alle Blöcke", "", "| Block | Anzahl | Knoten | Knotentypen |", "|---|---:|---:|---|"]
    for name, group in merged(blocks):
        same = all(b["kinds"] == group[0]["kinds"] for b in group)
        kinds = (
            ", ".join(f"{k}×{v}" for k, v in sorted(group[0]["kinds"].items()) if k != "comment")
            if same
            else ", ".join(sorted({k for b in group for k in b["kinds"] if k != "comment"})) + " (je Block verschieden)"
        )
        nodes = f"{min(b['n'] for b in group)}–{max(b['n'] for b in group)}" if len({b["n"] for b in group}) > 1 else str(group[0]["n"])
        out.append(f"| {name} | {len(group)} | {nodes} | {kinds[:150]} |")
    out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    export_path = Path(sys.argv[1])
    blocks, named = extract(export_path)
    sys.stdout.write(render(blocks, named, export_path))
    print(f"{len(blocks)} blocks from {export_path.name}, {named} named objects", file=sys.stderr)
