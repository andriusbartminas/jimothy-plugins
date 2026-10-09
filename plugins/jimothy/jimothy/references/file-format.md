# Jimothy file format, version 2

The exact shape of every file in `.planning/jimothy/`. Jimothy parses these files, so field names and allowed values matter. Unknown fields are ignored, so you may add extra fields, but never rename these ones.

Contents:
- Identifiers and timestamps
- `project.yaml`
- `asks/<id>.md`
- `now/<session>.yaml`
- `priorities.yaml`
- `log/<date>-<session>.md`
- `followups.yaml`
- Item references
- Changes from version 1

## Identifiers and timestamps

- **Timestamps** are ISO 8601 with a timezone offset: `2026-10-07T16:52:00+03:00`.
- **Ask id**: `YYYYMMDD-HHMM-<slug>`, where the slug is two to five lowercase words joined by hyphens. Example: `20261007-1652-keep-old-bucket`. The file name is the id plus `.md`. If the file already exists, add `-2`, `-3` and so on.
- **Session id**: whatever your harness gives you (a Claude Code session id, a Cursor chat id). If you have none, use `<agent>-<HHMM>`, for example `claude-1652`.
- **Agent name**: `claude-code`, `cursor`, `codex`, or the person's name for human-written entries.
- **Task name**: what a person would call the work, two to four words, sentence case: `Backup clean-up`, `Restore test`, `Customer table sync`. Use the same name in `now/`, asks and logs so Jimothy can link them.
- **Free text is always double-quoted**: names, titles, summaries, tasks, costs, option labels and notes. A colon followed by a space inside an unquoted value (`summary: Second brain: private`) makes the whole file invalid YAML, and Jimothy cannot open it. Escape any double quote inside the text as `\"`.

## project.yaml

```yaml
version: 2
name: "Atlas"
summary: "Kids' Minecraft server on Azure, always joinable at a fixed address."
status: active          # active | paused | shipped
owner: "Robin"
gsd: true               # true if .planning/STATE.md exists
commit: true            # false = opted out; files stay local via .git/info/exclude
ship_at: 2026-10-08T18:00:00+03:00   # planned go-live; null if none is stated
working_hours:          # optional; defaults to 08:00-20:00 local time
  start: "08:00"
  end: "20:00"
links:                  # optional; any of these
  repo: https://github.com/example/atlas
  docs: docs/
autostart: off          # optional: off | on. Whether Jimothy wakes agents itself when the human answers; the human sets it
agents:                 # optional; agent GitHub logins and the role each asks as
  sh-atlas-dev: developer
  sh-atlas-design: designer
```

Only set `ship_at` from a date someone actually stated (a roadmap, a brief, the user). Jimothy compares it with progress to show "on track" or "2h behind", so an invented date is worse than none.

`autostart` is the human's setting. Do not change it. With `off`, an answered ask or GitHub question shows a Resume button in Jimothy, which opens a new session with the prompt filled in. With `on`, Jimothy also writes the answer to the inbox for agents that are still open and, if nobody claims it within a couple of minutes and nobody is working in the project, starts an agent in the background in the checkout the ask is in, with limited permissions and as the agent account. That last step needs the human's own switch for the project in Jimothy's settings (not this file, which agents can edit) and a finished setup, and is described in `docs/design/background-resume.md`.

`agents` names the GitHub accounts your agents comment from. Jimothy treats their @-mentions of the human as questions from that role. An agent that posts under the human's own account is recognised by the opening of its comment instead (`Developer agent (session):`), and needs no entry here.

## asks/\<id\>.md

YAML frontmatter followed by up to four sections. You write the frontmatter, `## Context` and `## Prepared`. Jimothy writes the answer fields and `## Answer`. You write `## Resolution` when closing.

```markdown
---
version: 2
id: 20261007-1652-keep-old-bucket
type: decision            # decision | approval | task
status: open              # upcoming | open | answered | closed
title: "Keep the old storage bucket after migration?"
task: "Backup clean-up"   # the work that is waiting, in task language
cost: "Backup clean-up has stopped. About 6 PRs of work are queued behind it."
risk: irreversible        # reversible | irreversible
holding: true             # true = the work named in task has stopped
assumed: null             # option id you carried on with, when holding is false
expected_at: null         # upcoming only: when you expect to need the answer
needed_by: null           # optional: the real date the answer or action is needed by
asked_by: claude-code
role: developer            # optional: your role on the team (product-owner, developer, designer)
session: 8425c068
cli_session: 7c1d2f0e-0000-4000-8000-0000000000aa   # optional: this session's Claude Code id, from `scripts/jimothy-inbox.sh session-id`
asked_at: 2026-10-07T16:52:00+03:00
branch: backup-restore
phase: "04"               # GSD phase number, if any
plan: "04-02"             # GSD plan id, if any
options:
  - id: keep-30
    label: "Keep for 30 days"
    recommended: true
  - id: delete-now
    label: "Delete once the migration is verified"
  - id: keep
    label: "Keep it permanently"
# Written by Jimothy. Leave these alone.
answer: null              # option id, or "custom" for a free-text answer
answered_by: null
answered_at: null
# Written by you when closing.
closed_at: null
---

## Context

The new storage is live and verified, and the old bucket has had no reads for 9 days. Keeping it costs about 4 EUR a month and means a rollback stays possible. Deleting it cannot be undone.

## Prepared

## Answer

## Resolution
```

Field rules:

- `type`:
  - `decision` needs a choice between options.
  - `approval` is a yes or no on something you have prepared (a plan, a spend). Use options `approve` and `reject`. PR reviews do not need an ask: Jimothy reads open PRs from GitHub.
  - `task` is something only the human can do (add DNS records, grant access, sign something). Options are usually a single `done`, labelled with what they will have done ("Done, the records are in"). Put exactly what they need, ready to copy, in `## Prepared`.
- `task` is required. It is how Jimothy says what is waiting ("from Backup clean-up").
- `cost` is required, one or two sentences. Prefer a concrete measure of what is queued behind the ask (PRs, plans, a launch step); fall back to what has stopped and since when. For an `upcoming` ask, say what would stop if it were still unanswered when you get there.
- `risk` and `holding` follow the risk rule in SKILL.md. `risk: irreversible` always means `holding: true` once the ask is `open`.
- `assumed` is set only when `holding: false`, and must match one of the option ids.
- `expected_at` is set only for `upcoming` asks. A rough time is fine; it places the ask on the timeline.
- `role` is optional: your role on the team, when the project runs role agents (`product-owner`, `developer`, `designer`, or the role your instructions name). Jimothy groups the human's questions by it, so set it whenever you have one.
- `cli_session` is optional: the id of your Claude Code session, which `scripts/jimothy-inbox.sh session-id` prints. Jimothy uses it to continue this very conversation in the background when the answer arrives and nobody has picked it up, so the agent that comes back already knows the context. Leave it out if the command prints nothing. Jimothy only uses it if it is a UUID and a transcript with that id exists for the folder the ask is in.
- `needed_by` is optional, on any type and status. Set it only from a date that is actually known (a launch step, an expiring certificate, a client's deadline), never an invented one. `expected_at` says when you will reach the question; `needed_by` says when it is too late.
- `## Prepared` is optional: records, commands, text to paste. Jimothy shows it in a monospaced, copyable block. Leave it empty otherwise.
- Option labels become buttons. Phrase them as what will happen, short enough for a button (under about 40 characters).

Lifecycle:

1. You create it as `open`, or as `upcoming` for a decision you can see coming.
2. Jimothy sets `answered` and fills `answer`, `answered_by`, `answered_at` and `## Answer`. This can happen to an `upcoming` ask too, when the human decides early.
3. When you reach an `upcoming` ask that is still unanswered, set it to `open`, clear `expected_at`, and apply the risk rule.
4. You act on the answer and set `closed`, with `closed_at` and `## Resolution`. Every task offers the human a `done` answer (Jimothy adds it when you did not), often with a link or note in `## Answer`. Confirm the work where you can before closing, and say how you checked in the resolution. If the question stops mattering before anyone answers, close it yourself and say why in the resolution.

An ask you raised that is still `open` or `upcoming` more than 24 hours after `asked_at` gets re-checked at the start of your next session: bring its cost, context, `needed_by` or options up to date, or close it with a resolution if it no longer matters.

Anything left for the human to do or decide after the session ends must be an ask (usually `type: task`), not only a line in a log, a PR body or chat.

## now/\<session\>.yaml

One small file per running session, describing what you are doing right now. Never committed. Delete it when the session ends.

```yaml
version: 2
session: 8425c068
agent: claude-code
task: "Restore test"
state: running            # running | waiting
started_at: 2026-10-07T14:08:00+03:00
updated_at: 2026-10-07T14:20:00+03:00
branch: backup-restore
phase: "04"
plan: "04-02"
ask: null                 # when state is waiting: the id of the holding ask
```

- `started_at` is when you started this task, not the session. Update it, `task` and `updated_at` when you switch tasks.
- Set `state: waiting` and `ask` when you have stopped on a holding ask and are still in the session.
- Jimothy treats a file whose `updated_at` is several hours old as a session that ended without cleaning up.
- The optional permission hook adds `waiting_on: permission` while a permission prompt blocks the session (and `created_by: permission-hook` on a file it creates); its companion clears both once the session moves on. Do not write these fields yourself. A `state: waiting` file with no `ask` that has not changed for 10 minutes is shown as running (or hidden, if the hook created it), so always name the `ask` when you wait on one.

## priorities.yaml

Owned by the human. You read it and seed it once at setup, never edit it afterwards.

```yaml
version: 2
updated_at: 2026-10-07T17:05:00+03:00
updated_by: "Robin"
now:
  - ref: plan:04-02
  - ref: ask:20261007-1652-keep-old-bucket
next:
  - ref: phase:05
  - title: "Write a one-page runbook for restoring a backup"
    note: "Plain steps a non-engineer could follow."
later:
  - ref: todo:tidy-terraform-state
notes: "Backups before anything else this week."
```

Each entry has either a `ref` (an existing item) or a `title` (new work the human added). Treat a `title` entry as a request. If you start on it, mention it in your log. If it is big enough, propose turning it into a proper GSD phase or plan through an ask.

## log/\<date\>-\<session\>.md

One file per session, named `YYYY-MM-DD-<session>.md`. If a session spans midnight, use the start date.

```markdown
---
version: 2
session: 8425c068
agent: claude-code
started_at: 2026-10-07T14:10:00+03:00
ended_at: 2026-10-07T16:58:00+03:00
branch: backup-restore
phase: "04"
plan: "04-02"
tasks: ["Restore test", "Backup clean-up"]
asks_opened: [20261007-1652-keep-old-bucket]
asks_closed: []
---

## Changed
- Daily backups now run at 03:00 and keep 14 copies.
- Restore test passes against yesterday's backup.

## Next
- Weekly backup schedule, then plan 04-03.

## Stuck
- Backup clean-up is waiting on ask 20261007-1652-keep-old-bucket.
```

Write for the human, not for another agent: outcomes, not file lists or commit hashes. Three to six bullets in total is typical.

## followups.yaml

Agreed work that a session deferred to a later one ("left for later", "out of scope", "a follow-up PR"), on repos that do not use GitHub issues. On repos that do, file a follow-up issue instead and link it from the PR or the parent issue. Agents own this file: add your own entries, and mark them `done` or `dropped` when they are. Never move them into `priorities.yaml`; the human does that.

```yaml
version: 2
items:
  - id: 20261008-2240-owed-by-me-list
    title: "One list across projects of everything waiting on the owner"
    from: "issue:37"          # where it was deferred: pr:<n>, issue:<n> or log:<file stem>
    added_by: claude-code
    session: 8425c068
    added_at: 2026-10-08T22:40:00+03:00
    status: open              # open | done | dropped
    closed_at: null
    note: "Deferred from the first slice; needs needed_by on asks first."
```

- `id` uses the same format as an ask id.
- `title` is the work in plain words, double-quoted.
- Keep entries when they are done or dropped; set `status` and `closed_at`, and say why in `note` when dropping.

## Item references

Used in `priorities.yaml` and anywhere else you point at work:

| Ref | Points at |
|---|---|
| `phase:04` | GSD phase 04 |
| `plan:04-02` | GSD plan 04-02 |
| `todo:<file-stem>` | `.planning/todos/pending/<file-stem>.md` |
| `ask:<id>` | `.planning/jimothy/asks/<id>.md` |
| `pr:<number>` | Pull request on the project's repo |
| `issue:<number>` | Issue on the project's repo |
| `followup:<id>` | An entry in `.planning/jimothy/followups.yaml` |

## Inbox (written by Jimothy, in the git common directory)

Only for projects with `autostart: on`. When the human answers an ask, or replies on GitHub to an agent's question, Jimothy writes one record for it where every worktree of the repo can read it. The folder is `$(git rev-parse --git-common-dir)/jimothy/inbox/`. Git never commits it, and it is not part of the working copy.

```
inbox/<id>.json          # waiting for an agent
inbox/claimed/<id>.json  # an agent took it
inbox/claimed/<id>.by    # the session that took it (one line)
```

`<id>` is the ask id, or `gh-<owner>-<repo>-<issue number>` for a GitHub question (anything but letters, digits and `-` in the repository becomes `-`).

```json
{
  "id": "20261007-1652-keep-old-bucket",
  "kind": "ask",
  "title": "Keep the old storage bucket after migration?",
  "project": "Atlas",
  "session": "claude-backup",
  "role": "Developer",
  "answeredAt": "2026-10-09T10:29:04Z",
  "answer": "keep-30",
  "path": "/Users/me/Code/Atlas/.planning/jimothy/asks/20261007-1652-keep-old-bucket.md"
}
```

- `kind` is `ask` or `issue`. An ask carries `answer` (the option id) and `path`; an issue carries `url`.
- `session` is the session that asked: the ask's `session`, or the `(session)` in the opening of the agent's GitHub comment. It may be missing.
- A record is only a pointer. The ask file or the GitHub thread stays the record of what was decided; read it before acting.
- To claim a record, link it into `claimed/` without overwriting anything (`ln`, which fails if the claim exists, so only one agent wins), remove the inbox copy and write your session into `<id>.by`. `scripts/jimothy-inbox.sh claim` does this. Jimothy shows "picked up by <session>".
- Jimothy removes a waiting record as soon as its answer is gone (the ask is closed, or the thread has moved on). It keeps a claimed record for seven days after its answer first goes missing (noted in `claimed/<id>.gone`), so an answer that blinks out of one refresh is not delivered a second time. A newer answer to the same ask or thread replaces the old record and its claim.

## Changes from version 1

Jimothy reads both versions. When you edit a version 1 file, upgrade it:

- Asks: `type: question` becomes `decision`; `type: blocker` becomes `task`; `blocking` becomes `holding`; `blocks` is replaced by `cost`; add `task`.
- New: `status: upcoming` with `expected_at`, optional `needed_by` on asks, `followups.yaml`, the `## Prepared` section, `now/<session>.yaml`, `ship_at` and `working_hours` in `project.yaml`, `tasks` in log entries, and `status: shipped` (was `done`) in `project.yaml`.
