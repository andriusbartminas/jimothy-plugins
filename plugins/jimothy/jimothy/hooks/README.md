# Jimothy Claude Code hooks

When Claude Code is blocked on a permission prompt, this hook sets
`.planning/jimothy/now/<session>.yaml` to `state: waiting` so the dashboard
shows the project as waiting instead of still "running".

It never approves or denies the permission. Peon-ping and other hooks can keep
running on the same event.

## Install

With the Claude Code plugin (`/plugin install jimothy@jimothy-plugins`), these hooks are installed and kept up to date for you (`hooks.json`); nothing else to do.

Without the plugin, from a source checkout:

```bash
./skill/jimothy/hooks/install.sh
```

Then merge the printed `PermissionRequest`, `PostToolUse`, `UserPromptSubmit` and `Stop` entries
into `~/.claude/settings.json`. Where an event already has entries, add these to its list.

Self-test: `./skill/jimothy/hooks/test-hooks.sh` runs every hook against synthetic stdin JSON in a
throwaway folder.

## Behaviour

- Skips repos without `.planning/jimothy/`
- Updates an existing `now/` file for the session when possible, tagging it `waiting_on: permission`
- Creates a short waiting file if none exists (`task: Waiting on permission`, `created_by: permission-hook`)
- Always exits 0

## Clearing the wait

`jimothy-permission-clear.sh` runs on `PostToolUse` (the approved tool has run), `UserPromptSubmit`
(you typed, often after denying) and `Stop` (the reply ended). For the same session id it:

- deletes the `now/` file the permission hook created;
- sets `state: running` on an agent's own file that the hook marked waiting, keeping its task;
- leaves alone a wait the agent set itself on an ask (`ask:` names an ask id), and every other session's file.

It runs after every tool call, so it checks the session's file with `grep` first and starts Python
only when that file is waiting (about 20 ms when there is nothing to do). It is async and always exits 0.

If a session crashes before it can clear, Jimothy itself stops showing the wait: a `state: waiting`
file with no `ask` that has not changed for 10 minutes (neither `updated_at` nor the file) counts as
stale. A file the hook created is hidden; an agent's file shows as running. A real permission prompt
left unanswered for over 10 minutes therefore drops off the board too, though the session still shows it.

## No buried questions (Stop)

`jimothy-no-buried-question.sh` runs when Claude Code is about to end its reply. If the reply's
last paragraph ends with a question for the human and the turn did not use `AskUserQuestion`, it
blocks once with a reason: ask it with `AskUserQuestion` (two to four options, recommendation
first), or file a Jimothy ask if the answer will not come in this session.

- Only in projects with `.planning/jimothy/`
- Never blocks twice in a row (`stop_hook_active`), so a rhetorical question costs one extra turn at most
- Code blocks are ignored; questions earlier in the reply are fine
- Exits 0 on any error, so a broken transcript never stops a session
