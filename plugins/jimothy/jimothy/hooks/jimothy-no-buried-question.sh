#!/usr/bin/env bash
# Claude Code Stop hook: stop a reply that ends with a question buried in prose.
# Installed by the jimothy Claude Code plugin, or by hand with skill/jimothy/hooks/install.sh
# A question for the human is either an interactive choice (AskUserQuestion) or a Jimothy ask;
# a question at the end of a long reply is skimmed past and never comes back. When the last
# reply ends with one, the agent is sent back once to ask it properly. Never blocks twice in a row
# (stop_hook_active), and only in projects that report to Jimothy.
set -uo pipefail

INPUT=$(cat || true)

python3 -I - "$INPUT" <<'PY'
import json, os, re, sys
from pathlib import Path

try:
    data = json.loads(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].strip() else {}
except Exception:
    sys.exit(0)

if data.get("stop_hook_active"):
    sys.exit(0)

cwd = Path(data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
if not (cwd / ".planning" / "jimothy").is_dir():
    sys.exit(0)

transcript = data.get("transcript_path")
if not transcript or not Path(transcript).is_file():
    sys.exit(0)

def last_turn(path):
    """Text and tool names of the assistant messages since the last user prompt."""
    texts, tools = [], []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            try:
                entry = json.loads(raw)
            except Exception:
                continue
            kind = entry.get("type")
            content = (entry.get("message") or {}).get("content")
            if kind == "user" and isinstance(content, str):
                texts, tools = [], []           # a new human prompt starts a new turn
                continue
            if kind == "user" and isinstance(content, list) and any(
                isinstance(c, dict) and c.get("type") == "text" for c in content
            ):
                texts, tools = [], []
                continue
            if kind != "assistant" or not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text":
                    texts.append(block.get("text") or "")
                elif block.get("type") == "tool_use":
                    tools.append(block.get("name") or "")
    return texts, tools

texts, tools = last_turn(transcript)
if not texts or "AskUserQuestion" in tools:
    sys.exit(0)

final = texts[-1]
final = re.sub(r"```.*?```", "", final, flags=re.S).strip()   # code blocks do not count
paragraphs = [p.strip() for p in re.split(r"\n\s*\n", final) if p.strip()]
if not paragraphs:
    sys.exit(0)
last = paragraphs[-1]
# The closing paragraph asks something of the human: it ends with a question mark,
# or its last sentence does.
sentences = [s for s in re.split(r"(?<=[.!?])\s+", last) if s.strip()]
if not sentences or not sentences[-1].rstrip(" *_)\"'").endswith("?"):
    sys.exit(0)

print(json.dumps({
    "decision": "block",
    "reason": (
        "Your reply ends with a question for the human in prose. People skim long replies, so it will "
        "not be answered. Ask it with AskUserQuestion (two to four options, recommendation first), "
        "or if the answer will not come in this session, file it as a Jimothy ask "
        "(.planning/jimothy/asks/). If it was rhetorical, end the reply without it."
    ),
}))
PY
exit 0
