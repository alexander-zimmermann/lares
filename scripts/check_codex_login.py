"""Check one Hermes profile's Codex login against its model source's account rule.

    task agents:check-codex-login [<handle>]

The task reads the rule from persons.yaml and pipes this script into the Hermes
container, where it runs on the image's python3 and reads every profile's
auth.json under HERMES_HOME as a plain file: `hermes auth list` may write the
store. It prints one verdict, never a token or an account id.

A profile without Codex rows of its own reads the default profile's login, per
provider and without a switch, so a person who never ran `auth add` chats on
the owner's subscription. `hermes -p <handle> model` writes only the singleton
block, and the next pool load puts that token into the default profile's row.
An account is the token's `chatgpt_account_id` claim.

Verdicts, exit 0 for `ok` and 1 for any other:
- `missing`: the default profile holds no Codex login;
- `borrowed`: a person's profile holds none of its own;
- `half`: it holds the singleton block and no pool rows;
- `dead`: Hermes marked a row dead;
- `no_account`: no row's token names an account, so the rule cannot be checked;
- `other_account`: a `shared-with-default` profile holds an account the default profile does not;
- `shared_account`: a `per-person` profile is on an account another profile holds.
"""

from __future__ import annotations

import base64
import json
import os
import sys
from pathlib import Path
from typing import Any, NamedTuple

DEFAULT = "default"
CODEX = "openai-codex"
RULES = ("shared-with-default", "per-person")


class Verdict(NamedTuple):
    name: str
    reason: str


def _store(directory: Path) -> dict[str, Any]:
    """A profile's auth.json; Hermes reads a missing or corrupt one as empty, and so does this."""
    try:
        return json.loads((directory / "auth.json").read_text(encoding="utf-8-sig"))
    except (FileNotFoundError, ValueError):
        return {}


def _rows(store: dict[str, Any]) -> list[dict[str, Any]]:
    return store.get("credential_pool", {}).get(CODEX, [])


def _accounts(rows: list[dict[str, Any]]) -> set[str]:
    """The `chatgpt_account_id` claims of the rows' access tokens, read without the signature."""
    accounts = set()
    for row in rows:
        payload = row["access_token"].split(".")[1]
        claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        account = claims.get("https://api.openai.com/auth", {}).get("chatgpt_account_id")
        if account:
            accounts.add(account)
    return accounts


def verdict(home: Path, profile: str, rule: str) -> Verdict:
    directory = home if profile == DEFAULT else home / "profiles" / profile
    store = _store(directory)
    rows = _rows(store)
    if not rows:
        if profile == DEFAULT:
            return Verdict("missing", "no Codex login; event and cron runs answer from the fallback")
        if CODEX in store.get("providers", {}):
            return Verdict("half", "a login without pool rows, as `hermes model` leaves it")
        return Verdict("borrowed", "no Codex login of its own, so Hermes lends it the default's")
    if any(row.get("last_status") == "dead" for row in rows):
        return Verdict("dead", "Hermes marked its login dead")
    own = _accounts(rows)
    if not own:
        return Verdict("no_account", "its token names no ChatGPT account to check the rule against")
    if profile == DEFAULT:
        return Verdict("ok", "a Codex login of its own")
    default_accounts = _accounts(_rows(_store(home)))
    if rule == "shared-with-default":
        if not default_accounts:
            return Verdict("missing", "the default profile holds no Codex login to share")
        if own <= default_accounts:
            return Verdict("ok", "its own Codex login, on the default profile's account")
        return Verdict("other_account", "on an account the default profile does not hold")
    others = set(default_accounts)
    for other in (home / "profiles").iterdir():
        if other.is_dir() and other.name != profile:
            others |= _accounts(_rows(_store(other)))
    if own & others:
        return Verdict("shared_account", "on an account another profile holds")
    return Verdict("ok", "its own Codex login, on an account no other profile holds")


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in RULES:
        print(f"usage: check_codex_login.py <profile> <{'|'.join(RULES)}>", file=sys.stderr)
        return 2
    profile, rule = argv
    result = verdict(Path(os.environ["HERMES_HOME"]), profile, rule)
    print(f"{profile}: {result.name} — {result.reason}")
    return 0 if result.name == "ok" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
