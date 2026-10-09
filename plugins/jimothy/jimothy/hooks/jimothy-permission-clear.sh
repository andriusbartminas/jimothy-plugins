#!/usr/bin/env bash
# Claude Code PostToolUse / UserPromptSubmit / Stop hook: undo jimothy-permission-now.sh once the
# session has moved on, so the board does not keep a "Waiting on permission" pill.
# Installed by the jimothy Claude Code plugin, or by hand with skill/jimothy/hooks/install.sh
# Touches only this session's now/ file: deletes it when the permission hook created it, or sets
# `state: running` on an agent-written file the hook marked as waiting. A wait the agent set itself
# (holding on an ask) is left alone. Always exits 0.
set -uo pipefail

INPUT=$(cat || true)

# Fast path: this runs after every tool call, so skip Python unless this session's file is waiting.
sid=$(printf '%s' "$INPUT" | grep -o '"session_id" *: *"[^"\\]*"' | head -1 | sed 's/.*: *"//; s/"$//')
dir=$(printf '%s' "$INPUT" | grep -o '"cwd" *: *"[^"\\]*"' | head -1 | sed 's/.*: *"//; s/"$//')
dir=${dir:-${CLAUDE_PROJECT_DIR:-$PWD}}
safe=$(printf '%s' "${sid:-claude}" | cut -c1-64 | tr -c 'A-Za-z0-9._-' '-')
if [ -n "$sid" ] && ! grep -qs '^state: *waiting' "$dir/.planning/jimothy/now/${safe:-claude}.yaml"; then
  exit 0
fi

python3 -I - "$INPUT" <<'PY' || true
import json, os, re, sys
from datetime import datetime
from pathlib import Path

raw = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    sys.exit(0)

cwd = Path(data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
now_dir = cwd / ".planning" / "jimothy" / "now"
session = str(data.get("session_id") or "claude")[:64]
safe = re.sub(r"[^A-Za-z0-9._-]", "-", session) or "claude"
target = now_dir / f"{safe}.yaml"
if not target.is_file():
    sys.exit(0)

text = target.read_text(encoding="utf-8")

def field(key):
    m = re.search(rf"(?m)^{re.escape(key)}:[ \t]*(.*?)[ \t]*$", text)
    return m.group(1).strip().strip("\"'") if m else ""

if field("state") != "waiting":
    sys.exit(0)

created_by_hook = field("created_by") == "permission-hook" or field("task") == "Waiting on permission"
holding_on_ask = field("ask") not in ("", "null", "~")

if created_by_hook and not holding_on_ask:
    target.unlink(missing_ok=True)
    sys.exit(0)

if field("waiting_on") != "permission" and holding_on_ask:
    sys.exit(0)   # the agent is waiting on an ask; not ours to clear

stamp = datetime.now().astimezone().isoformat(timespec="seconds")
text = re.sub(r"(?m)^waiting_on:.*\n?", "", text)
if not holding_on_ask:
    text = re.sub(r"(?m)^state:.*$", "state: running", text, count=1)
if re.search(r"(?m)^updated_at:", text):
    text = re.sub(r"(?m)^updated_at:.*$", f"updated_at: {json.dumps(stamp)}", text, count=1)
else:
    text = text.rstrip() + f"\nupdated_at: {json.dumps(stamp)}\n"
tmp = target.with_suffix(".yaml.tmp")
tmp.write_text(text, encoding="utf-8")
os.replace(tmp, target)
PY

exit 0
