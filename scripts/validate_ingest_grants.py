"""Check that the ingest role may write every table the streams insert into.

    uv run --no-project python scripts/validate_ingest_grants.py

`grants.sql` names the tables the `connect` role gets INSERT and SELECT on,
one array entry each, and revokes everything else in `public` before handing
them out. That array is the whole permission surface of the ingest path: a
Redpanda Connect stream whose target is missing from it does not fail at
deploy time, it fails on the first message with "permission denied", once the
pipeline is already live.

The two sides have to say the same thing, so this reads both and compares:
the `INSERT INTO <table>` of every stream against the array. A stream without
a grant is the breaking case; a grant without a stream is a privilege nobody
asked for. Both are reported, both fail.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GRANTS = REPO / "kubernetes/applications/timescaledb/base/scripts/grants.sql"
STREAMS = REPO / "kubernetes/applications/redpanda-connect/base/streams"


def granted_tables(grants_sql: str) -> set[str]:
    """The array of the `ingest_table` loop, and only that array."""
    loop = re.search(
        r"FOREACH\s+ingest_table\s+IN\s+ARRAY\s+ARRAY\[(.*?)\]", grants_sql, re.DOTALL
    )
    if loop is None:
        sys.exit(f"{GRANTS.relative_to(REPO)}: no `FOREACH ingest_table IN ARRAY` loop found")
    return set(re.findall(r"'([^']+)'", loop.group(1)))


def inserted_tables(stream_dir: Path) -> dict[str, set[str]]:
    """Table -> the stream files inserting into it."""
    targets: dict[str, set[str]] = {}
    for stream in sorted(stream_dir.glob("*.yaml")):
        for table in re.findall(r"INSERT\s+INTO\s+([a-z_][a-z0-9_]*)", stream.read_text()):
            targets.setdefault(table, set()).add(stream.name)
    return targets


def main() -> int:
    granted = granted_tables(GRANTS.read_text())
    inserted = inserted_tables(STREAMS)

    ungranted = sorted(set(inserted) - granted)
    unused = sorted(granted - set(inserted))

    for table in ungranted:
        streams = ", ".join(sorted(inserted[table]))
        print(f"ERROR: {streams} inserts into `{table}`, which grants.sql does not grant.")
    for table in unused:
        print(f"ERROR: grants.sql grants `{table}`, which no stream inserts into.")

    if ungranted or unused:
        print(f"\nFix the array in {GRANTS.relative_to(REPO)} so it names exactly the "
              f"tables the streams write.")
        return 1

    print(f"OK: {len(granted)} ingest tables, grants.sql and the streams agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
