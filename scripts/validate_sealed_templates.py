"""Check that every key a SealedSecret template names is sealed.

    uv run --no-project --with pyyaml python scripts/validate_sealed_templates.py

A SealedSecret's `spec.template.data` composes files from its sealed keys,
`{{ index . "lares-mcp-key" }}` or `{{ .token }}`. The controller renders a key
the SealedSecret does not seal as an empty string, without an error, so a typo
or a key never sealed reaches the pod as an empty value. This check is the only
gate.

kubeseal rewrites `sealed-secret.yaml` whole, so a template sits in a patch
beside it. A template is checked against the SealedSecrets of the same name and
namespace in its own directory; one whose SealedSecret is not there fails too.
"""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path
from typing import NamedTuple

import yaml

REPO = Path(__file__).resolve().parent.parent
MANIFESTS = REPO / "kubernetes"

ACTION = re.compile(r"{{-?(.*?)-?}}", re.DOTALL)
INDEXED = re.compile(r'\bindex\s+\.\s+"([^"]+)"')
STRING = re.compile(r'"(?:[^"\\]|\\.)*"')
# A field of the root, `.token`; never one of a value, `$x.token` or `(…).token`.
FIELD = re.compile(r"(?<![\w.)\]$])\.([A-Za-z_]\w*)")


class Secret(NamedTuple):
    namespace: str
    name: str


class Template(NamedTuple):
    path: Path
    secret: Secret
    file: str
    text: str


def named_keys(template: str) -> set[str]:
    """The sealed keys one template's actions read."""
    keys: set[str] = set()
    for action in ACTION.findall(template):
        keys.update(INDEXED.findall(action))
        keys.update(FIELD.findall(STRING.sub('""', action)))
    return keys


def sealed_secrets(path: Path) -> list[dict]:
    """The SealedSecret documents of one file."""
    documents = yaml.safe_load_all(path.read_text(encoding="utf-8"))
    return [doc for doc in documents if isinstance(doc, dict) and doc.get("kind") == "SealedSecret"]


def main() -> int:
    sealed: dict[Path, dict[Secret, set[str]]] = defaultdict(lambda: defaultdict(set))
    templates: list[Template] = []

    for path in sorted(MANIFESTS.rglob("*.yaml")):
        if "charts" in path.parts or "kind: SealedSecret" not in path.read_text(encoding="utf-8"):
            continue
        for doc in sealed_secrets(path):
            secret = Secret(doc["metadata"]["namespace"], doc["metadata"]["name"])
            spec = doc["spec"]
            if "encryptedData" in spec:
                sealed[path.parent][secret].update(spec["encryptedData"])
            for file, text in spec.get("template", {}).get("data", {}).items():
                templates.append(Template(path, secret, file, text))

    errors = 0
    for template in templates:
        where = template.path.relative_to(REPO)
        name = template.secret.name
        held = sealed[template.path.parent]
        if template.secret not in held:
            print(
                f"ERROR: {where}: {name} ({template.secret.namespace}) has no SealedSecret beside it."
            )
            errors += 1
            continue
        for key in sorted(named_keys(template.text) - held[template.secret]):
            print(
                f"ERROR: {where}: {name}/{template.file} names `{key}`, which {name} does not seal."
            )
            errors += 1

    if errors:
        print(
            "\nSeal the missing keys (task k8s:seal) or fix the template: Sealed Secrets "
            "renders a key it does not hold as an empty value."
        )
        return 1

    print(f"OK: {len(templates)} SealedSecret templates name only sealed keys")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
