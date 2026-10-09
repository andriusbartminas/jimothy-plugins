---
name: jimothy
description: Keeps a project visible and steerable from Jimothy, the human's macOS command centre for AI projects, by maintaining a small set of files in .planning/jimothy/ (asks, running tasks, priorities, session logs, project manifest). Use this skill at the start and end of every working session in a project that has a .planning/jimothy/ folder or whose CLAUDE.md or AGENTS.md mentions Jimothy, and in those projects whenever you need a decision, approval or action from a human, can see a decision coming, are about to bury a question or a to-do for the human in chat or a log, or are choosing what to work on next. Also use it when the user asks to set a project up for Jimothy or for their dashboard. Use it even if the user never mentions Jimothy in the chat, and especially when several agents or people work on the same project.
---

# Jimothy

Jimothy is a dashboard the human keeps open all day. For every project it shows what is held up because of them and what that costs, whether the project will still ship on time, and what is in their review queue. It is read from files you maintain. If you skip them, the project goes dark on the dashboard and your questions never reach the human.

The human runs many projects with several agents each, at a pace of dozens of PRs a day. They do not read chat scrollback or planning prose to find out what you need. They read Jimothy. So anything that needs a human goes into a file Jimothy understands, and every session leaves a short, plain-English trace.

Jimothy describes **the work, not the workers**: rows say "Backup clean-up is waiting", not "Agent 2 is waiting". Name things by the task you are doing, in a few plain words, everywhere you write.

## Which projects

Jimothy is opt-in per project. Follow this skill only when one of these is true:

- the repo has a `.planning/jimothy/` folder;
- the repo's `CLAUDE.md` or `AGENTS.md` mentions Jimothy;
- the user asks you to set this project up for Jimothy (or "for my dashboard").

Otherwise do nothing Jimothy-related: do not create files, and do not suggest setting it up unprompted. Many repos belong to clients or teams, and Jimothy files there must be the owner's choice.

## The files

Everything lives in `.planning/jimothy/` at the repo root, whether or not the project uses GSD.

| Path | Who writes it | What it is for |
|---|---|---|
| `project.yaml` | You, once; update when status or ship date changes | Name, summary, status, ship date, working hours |
| `asks/<id>.md` | You create and close; Jimothy writes the answer | Decisions, approvals and tasks for the human, now or coming up |
| `now/<session>.yaml` | You, while a session runs. Never committed | The task you are doing right now |
| `priorities.yaml` | The human, through Jimothy. Read-only for you | Now / Next / Later order of work |
| `log/<date>-<session>.md` | You, at session end | What changed, what is next, what is stuck |
| `followups.yaml` | Agents. Add your own entries; mark them done or dropped | Agreed work deferred to a later session, on repos without GitHub issues |

Each file has one owner, so agents, people and the app never overwrite each other. Respect that: never edit `priorities.yaml`, and in an ask never touch the `## Answer` section or the answer fields.

Exact formats, field meanings and examples are in [references/file-format.md](references/file-format.md). Read it the first time you create any of these files in a session. Copyable templates are in `assets/templates/`.

## Session routine

### 1. Start: catch up before doing anything

1. If `.planning/jimothy/` does not exist, set the project up (see "Setting up a project" below).
2. Write `now/<session>.yaml` with the task you are about to do, so the dashboard shows the project as working.
3. Read every ask with `status: answered`, including early answers to `upcoming` asks. These are decisions the human made while you were away; act on them first. If you had carried on with an `assumed` option and the human chose differently, revisit that work before anything else. Undoing a wrong assumption early is cheap; building on it is not.
4. Re-check your own `open` and `upcoming` asks with an `asked_at` more than 24 hours ago (`asked_by` is your agent; on a shared project, also check `session`). Projects move at dozens of PRs a day, so a day-old ask has often been overtaken, and an old ask that nobody updates looks as urgent as a new one. Either bring it up to date (cost, context, `needed_by`, options) or, if it no longer matters, close it with a `## Resolution` saying why. Leave other agents' and people's asks alone.
5. Read `priorities.yaml`. Pick work from the top of `now` first, then `next`. If the user in this chat asks for something else, do what they ask; the chat wins over the file.
6. If the project uses GSD, read the frontmatter of `.planning/STATE.md` for the current position. Do not copy roadmap or state into Jimothy files; Jimothy reads GSD directly.

### 2. During work

**Keep `now/` current.** When you switch to a different task, update your `now/` file (task and `started_at`). Jimothy shows it as "Restore test · 12m", so the task name should be what a person would call the work. Optional Claude Code hook (`skill/jimothy/hooks/`) sets `state: waiting` when a permission prompt blocks the session, and its companion clears it once the session moves on — still write and delete `now/` yourself for normal start/end.

**Raise asks; do not bury questions.** Whenever you need a human decision, approval or action you cannot resolve from the code, docs, architecture decisions or sensible defaults, create an ask. If you work in a role on the team (product owner, developer, designer), set `role` on it, so the human can see who is asking and take questions role by role. Also set `cli_session` to the output of `scripts/jimothy-inbox.sh session-id` (leave it out if that prints nothing), so that if the answer arrives after you have gone Jimothy can bring you back with your context.

If the human is actively talking to you in this chat and can answer now, ask in chat instead, as a choice and never as prose. Use your client's interactive question tool (in Claude Code, `AskUserQuestion`) with two to four concrete options, your recommendation first. Never end a reply with a question in a paragraph ("Want me to file this?", "Shall I go ahead?"): people skim long replies, so a buried question is neither answered nor brought back, and nothing can act on it. If you have no question tool, or the answer will not come in this session, file an ask instead. Record the outcome where the project records decisions (GSD: `STATE.md` Decisions). File an ask when the answer will not come in this session, when it affects other agents or people, or when the session is about to end.

**Asking on GitHub.** When the discussion of a piece of work already lives on a GitHub issue, you may ask there instead of filing an ask: comment on the issue and @-mention the human's GitHub login. Jimothy shows the comment in the human's Needs you until they reply. If you post under the human's own account, open the comment with your role and your session in brackets, for example `Developer agent (issue-35): @login should the refresh stay at 5 minutes?`. Without both, Jimothy takes the comment for the human's own words (the human may write "Developer agent: yes" to reply to you), and the question never reaches them. On an agent account of your own, the opening is optional: the project lists the account under `agents:` in `project.yaml`, or the issue carries a `role:<your role>` label. A reply on GitHub does not reach you by itself, so at session start also read the issues where you asked.

Then decide whether the work waits. This depends on risk:

- **Reversible**: carry on with your recommended option. Set `holding: false` and `assumed: <option id>`. Say in the context which work depends on the assumption, so it can be found and undone if the human disagrees.
- **Irreversible or sensitive**: stop the affected work and set `holding: true`. Sensitive means:
  - deleting or migrating data
  - spending money or changing billing
  - production deploys or infrastructure changes
  - credentials, permissions or security posture
  - anything that reaches clients, users or the public
  - contractual or legal commitments
  - contradicting an agreed architecture decision

  Continue with other unblocked work if there is any. Otherwise end the session cleanly with a log entry.

When unsure which side something falls on, treat it as irreversible. A wrongly held task costs the human one click; a wrongly assumed deletion can cost a lot more.

**Say what it costs.** Every ask carries a `cost` sentence: what is waiting behind it, as concretely as you can. "About 6 PRs of work are queued behind it" beats "Plan 04-03 is blocked", which beats "Waiting for an answer". You know what is queued better than anyone; Jimothy sorts the human's attention by this sentence.

**Declare decisions you can see coming.** If you can tell that a decision will be needed later in this plan or the next (a retention period, a naming choice, a launch-day option), file it now with `status: upcoming` and an `expected_at` time. The human can decide it early, and then nobody stops when you get there. When you reach that point: if it has been answered, use the answer; if not, switch it to `open` and apply the risk rule as usual.

**Stay wakeable.** If the project has `autostart: on` (`scripts/jimothy-inbox.sh enabled` exits 0) and you are about to stop with something waiting on the human (a holding ask, or a question you asked on GitHub), do not simply go idle. Arm a Monitor, so Jimothy can hand you the answer and wake you:

1. Once, compute a deadline four hours ahead: `scripts/jimothy-inbox.sh deadline 4`. Keep that number; every re-arm uses the same one.
2. Start a Monitor with `timeout_ms` 1800000 and the command `scripts/jimothy-inbox.sh watch <your session> <deadline>` (the path is in this skill's folder). Say nothing about it to the human beyond what the turn needs.
3. When it ends without an answer (the 30-minute limit), and the deadline has not passed and the ask or question is still unanswered, re-arm with the same deadline, quietly, without commentary. At `WAIT-ENDED`, stop re-arming; the human gets a Resume button in Jimothy.
4. An `ANSWER <id> <record>` line means Jimothy has an answer for you. Run `scripts/jimothy-inbox.sh claim <id> <your session>`. If it prints `NOT-CLAIMED`, another agent took it: do nothing. If the record names a different role and not you, run `skip <id> <your session>` instead of claiming. Once claimed, the record is only a pointer: read the ask file or the GitHub thread it names, then act exactly as for an answered ask at the start of a session (step 1.3), and close the ask when done.

Your session name is the `session` you write in your asks and `now/` file. The monitor is only for your own asks and questions.

Whatever brings you to an answered ask (the monitor, the start-of-session read in step 1.3, or the human telling you), if the project has `autostart: on`, run `scripts/jimothy-inbox.sh claim <ask id> <your session>` before you act on it, and ignore `NOT-CLAIMED`. An unclaimed record makes Jimothy think nobody has picked the answer up, and after a couple of minutes it may start a second agent on it.

**Write asks for a busy person glancing at a dashboard between other tasks:**
- The title is the question itself, under about 70 characters.
- The context is a short paragraph, at most about six sentences: why it matters, what you found, and what each option leads to. No jargon the human would have to decode, and no internal GSD codes without saying what they are.
- Offer two to four concrete options and mark one `recommended`, unless you genuinely have no view. The recommended option's label becomes the primary button, so phrase it as what will happen: "Keep for 30 days", not "Option A".
- If the human has to do something themselves (add DNS records, grant access), use `type: task` and put exactly what they need, ready to copy, in `## Prepared`.
- If the answer or the action is needed by a known date (a launch step, an expiring certificate, someone else's deadline), set `needed_by`. Never invent one.
- Never include secrets, tokens or credential values in any Jimothy file. Name where a secret lives, never its value.

### 3. End: leave a trace

Before the session ends (the user says goodbye, the task is done, you hit a holding ask, or you sense the context is nearly full):

1. Turn anything left for the human into an ask, including any question you asked in chat that went unanswered. Something they must do later (add DNS records, confirm a policy, try a build for a day) is `type: task`; a choice they still have to make is `type: decision`. A log line, a chat message, a PR body or a "Next:" bullet is never enough on its own: nothing brings those back, so the to-do is forgotten. Set `needed_by` when you know a real date. The log may still mention the to-do, but name the ask id next to it. Reviewing and merging your PR needs no ask, because Jimothy already shows open PRs.
2. Track every follow-up you are leaving for a later session. When a wrap-up, PR body or log says something is "left for later", "out of scope", "a follow-up" or "not in this PR", each of those items must exist somewhere it will be picked up: on a repo that uses GitHub issues, a follow-up issue linked from the PR or the parent issue; otherwise an entry in `followups.yaml`. Then link each item (issue number or entry id) instead of only listing it. This is agent work deferred by agreement, not something the human must do; that is step 1.
3. Close asks you have acted on: set `status: closed` and `closed_at`, and fill in `## Resolution` with one or two sentences on what you did. A task answered `done` is the human's word, not proof: confirm the work where you can before closing (the records resolve, the page is live, the setting shows), and say how in the resolution. If it does not check out, leave the task open and say what is missing in `## Prepared`.
4. Write one log entry for the session. Keep each section to a few bullets in plain English: what changed, what is next, what is stuck. "Stuck" names the holding ask by id. An empty section says "Nothing".
5. Delete your `now/<session>.yaml`. A leftover file makes the dashboard claim work is running when it is not.
6. If the project uses GSD, make sure the `STATE.md` frontmatter (status, stopped_at, last_activity, progress) reflects reality, because Jimothy shows it as the headline.
7. If the project status or ship date changed, update `project.yaml`.

## Committing

Jimothy reads your local working copy directly, so the human sees your files as soon as you write them, with or without a remote. Commit them with your normal work, on the branch you are working on: that is how teammates' asks and logs reach Jimothy on other machines, because it also reads remote branches. Do not push to the main branch just to deliver these files; follow the project's usual branch and PR rules.

`now/` is never committed: it describes this machine at this moment. Setup adds it to `.gitignore`.

**Stacked PRs.** If your PR is based on another PR's branch, retarget it to the main branch (`gh pr edit <n> --base main`) as soon as the PR below it merges, before anyone merges yours. A PR still pointed at an already-merged branch merges into that branch, not into main, and the work silently never ships. Say in the PR body which PR it stacks on.

If `project.yaml` has `commit: false`, the project has opted out. Make sure `.planning/jimothy/` is listed in `.git/info/exclude` (local, never committed), and do not stage these files.

## Setting up a project

When `.planning/jimothy/` is missing:

1. Create `project.yaml` from the template. Fill `name` and a one-line `summary` from the README, `CLAUDE.md` or `.planning/PROJECT.md`. Set `status: active` and `commit: true` unless the user says otherwise. Set `gsd: true` if `.planning/STATE.md` exists. Fill `ship_at` only if a go-live date is stated somewhere; never invent one.
2. Create `asks/`, `log/` and `now/` folders (add a `.gitkeep` to `asks/` and `log/`), and add `.planning/jimothy/now/` to the repo's `.gitignore`.
3. Create `priorities.yaml` from the template with empty lists. It is the human's file; you are only seeding it.
4. If the project's `CLAUDE.md` (or `AGENTS.md`) does not mention Jimothy, add one line: `This project reports to Jimothy: follow the jimothy skill at the start and end of every session.`
5. Mention the setup in this session's log entry.

For a project without GSD, this is all Jimothy needs. Do not install GSD or invent a roadmap just for Jimothy.

## Several agents at once

Assume other agents and people may be working in the same repo or another worktree right now.

- Never edit an ask you did not create, except to close it once you have acted on its answer.
- Use the id format from the reference (timestamp plus a slug), so two agents never pick the same file name.
- Before creating an ask, check `asks/` for an open or upcoming one on the same question. If one exists, reference it rather than duplicating it.
- Your `now/` and log file names include your session id, so they never collide with anyone else's.
- In `followups.yaml`, add and close only your own entries, unless you have just done the work another entry describes; then mark it done and say so in its note.
