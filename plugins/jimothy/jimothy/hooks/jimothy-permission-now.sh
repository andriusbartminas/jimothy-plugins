#!/usr/bin/env bash
# Claude Code PermissionRequest hook: mark this project's Jimothy now/ as waiting.
# Installed by the jimothy Claude Code plugin, or by hand with skill/jimothy/hooks/install.sh
# Never auto-approves. Reads stdin JSON; updates .planning/jimothy/now/
# Tags what it writes (waiting_on: permission; created_by: permission-hook on a file it creates) so
# jimothy-permission-clear.sh can undo exactly that once the session moves on.
set -euo pipefail

INPUT=$(cat || true)

# Always exit 0 so Claude Code is never blocked by this observer hook.
python3 - "$INPUT" <<'PY' || true
import json, os, re, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path

raw = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

cwd = Path(data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
jimothy = cwd / ".planning" / "jimothy"
if not jimothy.is_dir():
    sys.exit(0)

now_dir = jimothy / "now"
now_dir.mkdir(parents=True, exist_ok=True)

session = str(data.get("session_id") or "claude")[:64]
safe = re.sub(r"[^A-Za-z0-9._-]", "-", session) or "claude"
tool = str(data.get("tool_name") or "tool")[:40]

stamp = datetime.now().astimezone().isoformat(timespec="seconds")
try:
    branch = subprocess.check_output(
        ["git", "-C", str(cwd), "rev-parse", "--abbrev-ref", "HEAD"],
        text=True,
        stderr=subprocess.DEVNULL,
    ).strip()
except Exception:
    branch = ""

# Only touch this session's file — never rewrite another agent's now/.
target = now_dir / f"{safe}.yaml"

def set_field(src: str, key: str, value: str) -> str:
    pat = re.compile(rf"(?m)^{re.escape(key)}:.*$")
    line = f"{key}: {value}"
    if pat.search(src):
        return pat.sub(line, src, count=1)
    return src.rstrip() + "\n" + line + "\n"

if target.exists():
    text = target.read_text(encoding="utf-8")
    text = set_field(text, "state", "waiting")
    text = set_field(text, "updated_at", json.dumps(stamp))
    text = set_field(text, "waiting_on", "permission")
    text = set_field(text, "agent", "claude-code")
    target.write_text(text, encoding="utf-8")
else:
    branch_line = json.dumps(branch) if branch else "null"
    target.write_text(
        "\n".join(
            [
                "version: 2",
                f"session: {safe}",
                "agent: claude-code",
                "task: Waiting on permission",
                "state: waiting",
                f'started_at: "{stamp}"',
                f'updated_at: "{stamp}"',
                f"branch: {branch_line}",
                "phase: null",
                "plan: null",
                "ask: null",
                "waiting_on: permission",
                "created_by: permission-hook",
                "",
            ]
        ),
        encoding="utf-8",
    )

# Tiny sidecar so Jimothy soft-reload can notice quickly (optional).
(now_dir / ".jimothy-hook-beat").write_text(f"{tool}\n{stamp}\n", encoding="utf-8")
PY

exit 0
