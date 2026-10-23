"""The week's skill digest: what each profile created, changed and archived, names only.

Hermes runs this as a cron job without a model (`no_agent: true`) and posts
its stdout to the home channel. Every profile keeps its own ledger of skill
changes, `skills/.curator_ledger.jsonl`, one JSON line per change with the
time, the action and the skill's name; this reads the default profile's and
each person's, keeps the seven days before now, and prints one block per
profile with a link to its skills page on the dashboard. The ledger holds
paths and hashes, never a skill's text, and neither does the digest.

A write to a repo skill never reaches the ledger: the skills under /opt/skills
are read-only to every profile, and Hermes logs the refused write in the
profile's `logs/errors.log` instead. Those skills get a line of their own. The
owner's became a pull request in lares unless it no longer applied to main,
which the trigger's log says; anyone else's stays this line.

Reads HERMES_HOME, the default profile's directory, which the image sets, and
HERMES_DASHBOARD_PUBLIC_URL, which the pod sets; exits 1 without them, which
Hermes reports as a failed job.
"""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

LEDGER = Path("skills") / ".curator_ledger.jsonl"
# Hermes's log of warnings and errors, and how many rotated ones it keeps beside it.
ERRORS_LOG = Path("logs") / "errors.log"
ROTATED = 2
# How the read-only mount refuses a skill write, as Hermes logs it
# (`%(asctime)s %(levelname)s%(session_tag)s %(name)s: %(message)s`, local time).
REFUSED = re.compile(
    r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ ERROR\b.*? tools\.registry: "
    r"Tool skill_manage dispatch error: \[Errno 30\] Read-only file system: "
    r"'/opt/skills/([^/']+)/"
)
WINDOW = timedelta(days=7)
# The ledger's action and what it did to the skill; every other action is no lesson.
CHANGES = {
    "create": "created",
    "patch": "changed",
    "edit": "changed",
    "write_file": "changed",
    "remove_file": "changed",
    "archive": "archived",
    "delete": "deleted",
}
# The line each change gets, in the order the digest shows them.
LABELS = {
    "created": "Neu",
    "changed": "Geändert",
    "archived": "Archiviert",
    "deleted": "Gelöscht",
    "refused": "Repo-Skill nicht geschrieben",
}
# Names per line; the rest is a count, and the dashboard has them all.
NAMES_PER_LINE = 8


def changes(ledger: Path, since: datetime) -> dict[str, set[str]]:
    """The skills changed since `since`, by what was done to them."""
    held: dict[str, set[str]] = {}
    if not ledger.is_file():
        return held
    for line in ledger.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip():
            continue
        entry = json.loads(line)
        change = CHANGES.get(entry["action"])
        if change is None or datetime.fromisoformat(entry["ts"]) < since:
            continue
        # A review's delete archives instead, which the ledger holds as its own line.
        if change == "deleted" and entry.get("evidence", {}).get("archived"):
            continue
        held.setdefault(change, set()).add(entry["skill"])
    # A skill made this week is new, however often it changed after.
    if "created" in held and "changed" in held:
        held["changed"] -= held["created"]
    return {change: names for change, names in held.items() if names}


def refused(errors_log: Path, since: datetime) -> set[str]:
    """The repo skills a write of this profile was refused on since `since`, by Hermes's log."""
    names: set[str] = set()
    rotated = (errors_log.with_name(f"{errors_log.name}.{n}") for n in range(1, ROTATED + 1))
    for log in (errors_log, *rotated):
        if not log.is_file():
            continue
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            found = REFUSED.match(line)
            if found and datetime.fromisoformat(found.group(1)) >= since:
                names.add(found.group(2))
    return names


def block(profile: str, held: dict[str, set[str]], dashboard: str) -> str:
    """One profile's lines: its skills page, then the names of each change it had."""
    lines = [f"**{profile}** · <{dashboard}/skills?profile={profile}>"]
    for change, label in LABELS.items():
        names = sorted(held.get(change, ()))
        if not names:
            continue
        shown = ", ".join(f"`{name}`" for name in names[:NAMES_PER_LINE])
        rest = len(names) - NAMES_PER_LINE
        lines.append(f"{label}: {shown}" + (f" und {rest} weitere" if rest > 0 else ""))
    return "\n".join(lines)


def main() -> int:
    missing = [
        name
        for name in ("HERMES_HOME", "HERMES_DASHBOARD_PUBLIC_URL")
        if not os.environ.get(name)
    ]
    if missing:
        print(f"skill-digest: {', '.join(missing)} not set", file=sys.stderr)
        return 1
    home = Path(os.environ["HERMES_HOME"])
    dashboard = os.environ["HERMES_DASHBOARD_PUBLIC_URL"].rstrip("/")
    since = datetime.now(UTC) - WINDOW
    # Hermes logs in the pod's local time, without a zone.
    since_local = datetime.now() - WINDOW

    profiles = {"default": home}
    profiles_dir = home / "profiles"
    if profiles_dir.is_dir():
        profiles.update(
            {
                entry.name: entry
                for entry in sorted(profiles_dir.iterdir())
                if entry.is_dir()
            }
        )

    blocks = []
    for profile, directory in profiles.items():
        held = changes(directory / LEDGER, since)
        if names := refused(directory / ERRORS_LOG, since_local):
            held["refused"] = names
        if held:
            blocks.append(block(profile, held, dashboard))

    print("**Skills der letzten 7 Tage**")
    print()
    if blocks:
        print("\n\n".join(blocks))
    else:
        print("Kein Profil hat einen Skill angelegt, geändert oder archiviert.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
