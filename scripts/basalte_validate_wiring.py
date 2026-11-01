"""Check the Studio export for logic nodes that can never fire.

    uv run --no-project python scripts/basalte_validate_wiring.py <export.bcfg>

A node whose output is wired but whose input is not stays silent forever,
and Studio draws it like any other: a Nummer einstellen without a trigger
never sends its number, a Vergleichen mit missing A never compares, a Tor
with nothing on in 1 never lets the end of a fault through. The freezer's
door watch sat like that for two weeks — the 80 mA threshold had no trigger,
so the stopwatch never ran, and a door left ajar overnight iced the freezer.

Only inputs a node cannot work without count. A node nothing reads from is
left alone: it may be dead, but it breaks nothing.

Any finding fails the run.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from basalte_export import parse

_BLOCK_FIELD = 100

# Inputs each node type needs before its output means anything. A tuple
# lists inputs that must all be wired; a number is how many of the node's
# own inputs must be. Types not listed are sources or devices.
_REQUIRED: dict[str, tuple[str, ...] | int] = {
    "setnumber": ("trigger",),
    "setbool": ("trigger",),
    "setpercentage": ("trigger",),
    "setstring": ("trigger",),
    "compare": ("A", "B"),
    "chrono": ("enable",),
    "oscillator": ("enable",),
    "not": ("in",),
    "debouncer": ("in",),
    "pacer": ("in",),
    "lookuptable": ("in",),
    "changedetector": ("trigger",),
    "delay": ("trigger",),
    "oneshot": ("trigger",),
    "add": ("in", "addend"),
    "subtract": ("in", "subtrahend"),
    "multiply": ("in", "multiplicand"),
    "divide": ("in", "dividend"),
    "modulo": ("in", "modulus"),
    "and": 2,
    "or": 2,
    "multiplexer": 1,
    "setreset": 1,
}
# Nodes with no output: wired in or useless.
_SINKS: dict[str, str] = {"linkoutput": "in", "notification": "trigger"}

# What the German Studio canvas calls the node and the port, so a finding
# reads like the screen; types without a known label keep their type name.
_NODE_LABEL = {
    "setnumber": "Nummer einstellen",
    "setbool": "Bool einstellen",
    "compare": "Vergleichen mit",
    "chrono": "Chrono",
    "not": "NICHT",
    "and": "UND",
    "gate": "Tor",
    "multiplexer": "MUX",
    "changedetector": "Änderungsdetektor",
    "setreset": "Set/Reset",
    "init": "Initialisieren",
}
_PORT_LABEL = {"enable": "aktivieren", "reset": "zurücksetzen", "trigger": "Trigger"}
_PORT_LABEL_BY_NODE = {("changedetector", "trigger"): "Wert"}


@dataclass(frozen=True, slots=True)
class Finding:
    block: str
    node: str
    problem: str


def _field(message: list, number: int) -> list:
    return [value for field, _kind, value in message if field == number]


def _node_name(model: dict) -> str:
    kind = model["name"].split("::")[-1]
    if kind in ("linkoutput", "linkinput"):
        return f"Link {model.get('linkName', '')}".rstrip()
    if kind == "notification":
        sink = "App" if model.get("sink") == "app" else "E-Mail"
        return f"{sink} Notification {model.get('subject', '')}".rstrip()
    label = _NODE_LABEL.get(kind, kind)
    if "triggerValue" in model:
        value = model["triggerValue"]
        return f"{label} {str(value).lower() if isinstance(value, bool) else value}"
    if "knxAddress" in model:
        return f"{label} {model['knxAddress']}"
    return label


def _port(kind: str, name: str) -> str:
    if (kind, name) in _PORT_LABEL_BY_NODE:
        return _PORT_LABEL_BY_NODE[(kind, name)]
    return f"in {name}" if name.isdigit() else _PORT_LABEL.get(name, name)


def _block_label(name: str, models: list[dict]) -> str:
    # Many blocks share a name ("Türe auf" ×4); what they link out to or
    # write is what tells them apart on the canvas.
    for key in ("linkName", "knxAddress"):
        tags = sorted({str(m[key]) for m in models if key in m})
        if tags:
            return f"{name} [{', '.join(tags[:2])}]"
    return name


def check_block(name: str, graph: dict, known_links: set[str]) -> list[Finding]:
    """Every node in one block that can never fire."""
    models = [node["model"] for node in graph["nodes"]]
    by_uuid = {m["uuid"].strip("{}"): m for m in models}
    wired_in: dict[str, set[str]] = {uuid: set() for uuid in by_uuid}
    feeds: set[str] = set()
    for edge in graph["connections"]:
        target, source = edge["in_id"].strip("{}"), edge["out_id"].strip("{}")
        if target in wired_in:
            wired_in[target].add(edge["in_key"])
        feeds.add(source)

    label = _block_label(name, models)
    findings: list[Finding] = []
    for uuid, model in by_uuid.items():
        kind = model["name"].split("::")[-1]
        ins = wired_in[uuid]
        node = _node_name(model)
        if kind in _SINKS:
            if _SINKS[kind] not in ins:
                findings.append(Finding(label, node, f"{_port(kind, _SINKS[kind])} has no wire"))
            continue
        if kind == "linkinput":
            if str(model.get("linkUuid", "")).strip("{}") not in known_links:
                findings.append(Finding(label, node, "points at no Link-Ausgang"))
            continue
        if uuid not in feeds:
            continue
        if kind == "gate":
            missing = [p for p in ("enable",) if p not in ins]
            data = [p for p in model.get("inputs", []) if p != "enable"]
            if not any(p in ins for p in data):
                missing.append(data[0] if data else "in 1")
        else:
            required = _REQUIRED.get(kind)
            if required is None:
                continue
            if isinstance(required, int):
                if len(ins) < required:
                    findings.append(
                        Finding(label, node, f"{len(ins)} of its inputs wired, needs {required}")
                    )
                continue
            missing = [p for p in required if p not in ins]
        if missing:
            ports = ", ".join(_port(kind, p) for p in missing)
            findings.append(Finding(label, node, f"{ports} has no wire"))
    return findings


def check_export(export: Path) -> tuple[int, list[Finding]]:
    blocks: list[tuple[str, dict]] = []
    for field, kind, value in parse(export.read_bytes()):
        if field != _BLOCK_FIELD or kind != "msg":
            continue
        graphs = [g for g in _field(value, 5) if isinstance(g, str) and '"nodes"' in g]
        if not graphs:
            continue
        names = [n for n in _field(value, 2) if isinstance(n, str)]
        blocks.append((names[0] if names else "(unnamed)", json.loads(graphs[0])))
    known_links = {
        str(node["model"]["linkUuid"]).strip("{}")
        for _name, graph in blocks
        for node in graph["nodes"]
        if node["model"]["name"].endswith("linkoutput") and "linkUuid" in node["model"]
    }
    findings = [f for name, graph in blocks for f in check_block(name, graph, known_links)]
    return len(blocks), findings


def main() -> int:
    export = Path(sys.argv[1])
    count, findings = check_export(export)
    print(f"{export.name}: {count} logic blocks")
    if not findings:
        print("no unwired input")
        return 0
    print(f"\n=== {len(findings)} nodes that can never fire")
    block = None
    for finding in sorted(findings, key=lambda f: (f.block, f.node)):
        if finding.block != block:
            block = finding.block
            print(f"  {block}")
        print(f"    {finding.node}: {finding.problem}")
    print("\nwire them in Studio, export again and commit")
    return 1


if __name__ == "__main__":
    sys.exit(main())
