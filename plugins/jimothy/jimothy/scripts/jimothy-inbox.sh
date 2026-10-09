#!/usr/bin/env bash
# Wait for Jimothy to hand over an answer, and claim it.
#
#   jimothy-inbox.sh enabled                    exit 0 if this project has `autostart: on`
#   jimothy-inbox.sh deadline <hours>           print an epoch time that many hours from now
#   jimothy-inbox.sh session-id                 print this session's Claude Code session id (for `cli_session:` in an ask)
#   jimothy-inbox.sh watch <session> <deadline> print one line per waiting answer for you, until the deadline
#   jimothy-inbox.sh claim <id> <session>       take an answer; exit 1 if another agent got there first
#   jimothy-inbox.sh skip <id> <session>        stop `watch` from reporting an answer that is not yours
#
# Run `watch` as a Monitor (timeout 1800000): each ANSWER line wakes an idle session. Records live in
# $(git rev-parse --git-common-dir)/jimothy/inbox/, shared by every worktree; the format is in
# references/file-format.md. Nothing here reads or prints anything but the record Jimothy wrote.
set -uo pipefail

inbox_dir() {
  # --git-common-dir is relative to the current folder when it is printed relative, so resolve it from here.
  local common
  common=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
  common=$(cd "$common" 2>/dev/null && pwd -P) || return 1
  printf '%s/jimothy/inbox' "$common"
}

# The session a record names, or empty.
record_session() {
  tr -d '\n' < "$1" | sed -n 's/.*"session" *: *"\([^"]*\)".*/\1/p'
}

cmd="${1:-}"
# When JIMOTHY_INBOX_LOG names a file, each call is noted there (epoch seconds, then the arguments). The skill
# evals use it to see what an agent did; it is off otherwise and nothing in the script reads it back.
if [ -n "${JIMOTHY_INBOX_LOG:-}" ]; then printf '%s %s\n' "$(date +%s)" "$*" >> "$JIMOTHY_INBOX_LOG" 2>/dev/null; fi
case "$cmd" in
  enabled)
    top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
    [ -f "$top/.planning/jimothy/project.yaml" ] || exit 1
    grep -Eiq '^autostart:[[:space:]]*(on|true|yes)([[:space:]]|$)' "$top/.planning/jimothy/project.yaml"
    ;;

  session-id)
    # The shell this runs in descends from the session's process, and `claude agents --json` lists that
    # process with its session id. Walk up the process tree until a pid is in the list.
    command -v claude >/dev/null 2>&1 || exit 1
    listing=$(claude agents --json 2>/dev/null | tr -d '\n ' | sed 's/},{/}\
{/g') || exit 1
    pid=$$
    while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
      id=$(printf '%s\n' "$listing" | grep "\"pid\":$pid[,}]" | sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' | head -1)
      if [ -n "$id" ]; then echo "$id"; exit 0; fi
      pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    exit 1
    ;;

  deadline)
    hours="${2:-4}"
    echo $(( $(date +%s) + hours * 3600 ))
    ;;

  watch)
    session="${2:?session}"
    deadline="${3:?deadline (epoch seconds)}"
    inbox=$(inbox_dir) || { echo "WAIT-ENDED not a git checkout"; exit 0; }
    # Skip lists only matter while an agent keeps waiting; drop the ones nobody has touched for a day.
    find "$inbox" -maxdepth 1 -name 'skipped.*' -mmin +1440 -exec rm -f {} + 2>/dev/null
    seen=" "
    while [ "$(date +%s)" -lt "$deadline" ]; do
      for f in "$inbox"/*.json; do
        [ -e "$f" ] || continue
        id=$(basename "$f" .json)
        case "$seen" in *" $id "*) continue ;; esac
        if [ -f "$inbox/skipped.$session" ] && grep -Fxq "$id" "$inbox/skipped.$session"; then continue; fi
        record_session_value=$(record_session "$f")
        if [ -n "$record_session_value" ] && [ "$record_session_value" != "$session" ]; then continue; fi
        seen="$seen$id "
        echo "ANSWER $id $(tr -d '\n' < "$f")"
      done
      sleep 5
    done
    echo "WAIT-ENDED deadline reached"
    ;;

  claim)
    id="${2:?id}"
    session="${3:?session}"
    inbox=$(inbox_dir) || exit 1
    mkdir -p "$inbox/claimed"
    # A hard link fails if the target exists, so of several agents claiming the same record exactly one
    # succeeds, and a record that is already claimed is never overwritten. `mv` would overwrite it.
    if ln "$inbox/$id.json" "$inbox/claimed/$id.json" 2>/dev/null; then
      rm -f "$inbox/$id.json"
      printf '%s\n' "$session" > "$inbox/claimed/$id.by"
      echo "CLAIMED $id"
    else
      echo "NOT-CLAIMED $id"
      exit 1
    fi
    ;;

  skip)
    id="${2:?id}"
    session="${3:?session}"
    inbox=$(inbox_dir) || exit 1
    mkdir -p "$inbox"
    printf '%s\n' "$id" >> "$inbox/skipped.$session"
    ;;

  *)
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
    ;;
esac
