# Temporary: write each Hermes "KEY is not set" warning's call path and scope to /tmp (key names only, never values).
import logging
import os
import sys
import threading
import time
import traceback

_ROOT = "/opt/hermes/"
_MAX_LINES = 5000
logger = logging.getLogger("miss_hook")
_lock = threading.Lock()
_local = threading.local()
_paths: dict = {}
_scopes: dict = {}
_lines = 0


def _write(text: str) -> None:
    global _lines
    if _lines >= _MAX_LINES:
        return
    _lines += text.count("\n")
    with open(f"/tmp/miss-stacks.{os.getpid()}.log", "a", encoding="utf-8") as fh:
        fh.write(text)


def _context() -> dict:
    from agent.secret_scope import (
        current_secret_scope,
        current_secret_scope_home,
        is_multiplex_active,
        serves_routed_profile,
    )
    from hermes_constants import get_hermes_home_override
    scope = current_secret_scope()
    return {"override": get_hermes_home_override(), "scope_home": current_secret_scope_home(),
            "scope_keys": None if scope is None else tuple(sorted(scope)),
            "multiplex": is_multiplex_active(), "routed": serves_routed_profile()}


def _capture(record: logging.LogRecord) -> None:
    stamp = time.strftime("%H:%M:%S", time.localtime(record.created)) + f".{int(record.msecs):03d}"
    args = record.args if isinstance(record.args, tuple) else ()
    key = args[1] if len(args) > 1 else "?"
    # Hermes frames only: the venv and the bundled stdlib (asyncio, logging) also live under /opt/hermes
    frames = [f for f in traceback.extract_stack()
              if f.filename.startswith(_ROOT) and "/.venv/" not in f.filename and "/lib/python3." not in f.filename]
    path = tuple((f.filename[len(_ROOT):], f.lineno, f.name, (f.line or "")[:100]) for f in frames)
    try:
        ctx, error = _context(), ""
    except (ImportError, AttributeError) as exc:  # a Hermes release renamed one of the scope helpers
        ctx, error = {}, f" ctx_error={exc!r}"
    out = []
    with _lock:
        if path not in _paths:
            _paths[path] = f"P{len(_paths) + 1}"
            out.append(f"--- {_paths[path]}\n"
                       + "".join(f"  {fn}:{ln} {name}: {line}\n" for fn, ln, name, line in path))
        scope_id = "none"
        if ctx.get("scope_keys") is not None:
            scope = (ctx["scope_home"], ctx["scope_keys"])
            if scope not in _scopes:
                _scopes[scope] = f"S{len(_scopes) + 1}"
                out.append(f"--- {_scopes[scope]} home={scope[0]} keys={','.join(scope[1]) or '-'}\n")
            scope_id = _scopes[scope]
        out.append(f"{stamp} thread={threading.current_thread().name} key={key} path={_paths[path]}"
                   f" override={ctx.get('override')} scope={scope_id} multiplex={ctx.get('multiplex')}"
                   f" routed={ctx.get('routed')}{error}\n")
        _write("".join(out))


class _MissCapture(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        # The busy flag stops a loop when formatting the failure record itself loads a config.
        if "is not set" in str(record.msg) and not getattr(_local, "busy", False):
            _local.busy = True
            try:
                _capture(record)
            except Exception:
                logger.exception("miss capture failed; the warning itself is unaffected")
            finally:
                _local.busy = False
        return True


logging.getLogger("hermes_cli.config").addFilter(_MissCapture())
_write(f"{time.strftime('%H:%M:%S')} loaded pid={os.getpid()} argv={' '.join(sys.argv)[:120]}\n")
