"""Check that every key a SealedSecret template or a Secret reference names is sealed.

    uv run --no-project --with pyyaml python scripts/validate_sealed_templates.py

A SealedSecret's `spec.template.data` composes files from its sealed keys,
`{{ index . "lares-gateway-key" }}` or `{{ .token }}`. The controller renders a key
the SealedSecret does not seal as an empty string, without an error, so a typo
or a key never sealed reaches the pod as an empty value. This check is the only
gate.

kubeseal rewrites `sealed-secret.yaml` whole, so a template sits in a patch
beside it. A template is checked against the SealedSecrets of the same name and
namespace in its own directory; one whose SealedSecret is not there fails too.

A key a manifest or a values file reads from a SealedSecret in its own
directory or one above it, by `secretKeyRef` or by a `secret` volume's
`items`, must be a key the Secret holds: sealed, or composed by a template. Kubernetes would refuse
to start the pod, after the merge. A reference to a Secret nobody seals
there, a clone or one an operator writes, is not checked.
"""

from __future__ import annotations

import re
from collections import defaultdict
from collections.abc import Iterator
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


class _Loader(yaml.SafeLoader):
    """Safe YAML that reads an application's own tags (`!Find` in a blueprint) as plain values."""


def _untagged(loader: yaml.SafeLoader, suffix: str, node: yaml.Node) -> object:
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    return loader.construct_scalar(node)


_Loader.add_multi_constructor("!", _untagged)


def references(node: object) -> Iterator[tuple[str, str]]:
    """Every (Secret, key) a `secretKeyRef` or a `secret` volume's `items` reads."""
    if isinstance(node, dict):
        ref = node.get("secretKeyRef")
        if isinstance(ref, dict) and "name" in ref and "key" in ref:
            yield ref["name"], ref["key"]
        volume = node.get("secret")
        if isinstance(volume, dict) and "secretName" in volume:
            for item in volume.get("items") or []:
                yield volume["secretName"], item["key"]
        for value in node.values():
            yield from references(value)
    elif isinstance(node, list):
        for value in node:
            yield from references(value)


def sealed_secrets(path: Path) -> list[dict]:
    """The SealedSecret documents of one file."""
    documents = yaml.safe_load_all(path.read_text(encoding="utf-8"))
    return [doc for doc in documents if isinstance(doc, dict) and doc.get("kind") == "SealedSecret"]


def main() -> int:
    sealed: dict[Path, dict[Secret, set[str]]] = defaultdict(lambda: defaultdict(set))
    # The keys each Secret holds, by directory and name: sealed, or composed by a template.
    holds: dict[Path, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    templates: list[Template] = []

    for path in sorted(MANIFESTS.rglob("*.yaml")):
        if "charts" in path.parts or "kind: SealedSecret" not in path.read_text(encoding="utf-8"):
            continue
        for doc in sealed_secrets(path):
            secret = Secret(doc["metadata"]["namespace"], doc["metadata"]["name"])
            spec = doc["spec"]
            if "encryptedData" in spec:
                sealed[path.parent][secret].update(spec["encryptedData"])
                holds[path.parent][secret.name].update(spec["encryptedData"])
            for file, text in spec.get("template", {}).get("data", {}).items():
                templates.append(Template(path, secret, file, text))
                holds[path.parent][secret.name].add(file)

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

    checked = 0
    for path in sorted(MANIFESTS.rglob("*.yaml")):
        if "charts" in path.parts:
            continue
        # The SealedSecrets beside the file and in each directory above it, the nearest first.
        around = [holds[d] for d in (path.parent, *path.parent.parents) if d in holds]
        if not around:
            continue
        for doc in yaml.load_all(path.read_text(encoding="utf-8"), Loader=_Loader):
            for name, key in references(doc):
                held = next((secrets[name] for secrets in around if name in secrets), None)
                if held is None:
                    continue
                checked += 1
                if key not in held:
                    where = path.relative_to(REPO)
                    print(f"ERROR: {where}: reads `{key}` of {name}, which {name} does not hold.")
                    errors += 1

    if errors:
        print(
            "\nSeal the missing keys (task k8s:seal) or fix the template or reference: Sealed "
            "Secrets renders a key it does not hold as an empty value, and a pod reading a "
            "missing key does not start."
        )
        return 1

    print(
        f"OK: {len(templates)} SealedSecret templates and {checked} references name only "
        "sealed keys"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
