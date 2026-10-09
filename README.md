# Jimothy plugins for Claude Code

[Jimothy](https://github.com/andriusbartminas/jimothy-plugins) is a macOS command centre for AI projects. It shows, for every project, what is held up because of you and what that costs, whether the project will still ship on time, and what is waiting in your review queue. Agents keep it up to date by writing a few small files in `.planning/jimothy/`.

This repository is a Claude Code plugin marketplace with one plugin, `jimothy`. It gives your agents:

- **The jimothy skill**: how to raise asks instead of burying questions in chat, keep the running task current, follow your priorities, and leave a short log at the end of each session.
- **Hooks**: a session waiting on a permission prompt shows as waiting on the board, and a reply that ends with a question for you is sent back once, to ask it properly. The hooks act only in projects that have a `.planning/jimothy/` folder.

## Install

In Claude Code:

```
/plugin marketplace add andriusbartminas/jimothy-plugins
/plugin install jimothy@jimothy-plugins
```

Then, in a project you want on the board, ask your agent to "set this project up for Jimothy". Projects without `.planning/jimothy/` are left alone.

If you installed the skill or its hooks by hand before, remove those copies first (the skill folder under `~/.claude/skills/jimothy`, and the Jimothy entries under `hooks` in `~/.claude/settings.json`), so nothing runs twice.

## Privacy

The skill and hooks run inside Claude Code on your Mac. They read and write only files under `.planning/jimothy/` in your projects, and send nothing anywhere.

## Licence

MIT. See [LICENSE](LICENSE).

This repository is published from the Jimothy source; changes are made there and copied here for each release.
