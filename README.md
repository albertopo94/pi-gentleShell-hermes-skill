# pi-gentleShell-hermes-skill — your `-own` delegation skills for Hermes

A family of local, user-owned [Hermes](https://hermes-agent.nousresearch.com)
skills that delegate coding tasks to terminal CLIs from a Hermes chat, the same
way the bundled `/claude-code`, `/codex` and `/opencode` skills drive their
CLIs. Each skill is a plain `SKILL.md` (an operation manual injected into the
agent context) — no integration code, no daemon, no network dependency beyond
your own setup.

The `-own` suffix namespaces every skill as **user-maintained** so they never
collide with future official skills from Nous. Both can coexist; to retire one,
delete its folder — nothing else references the name.

## The family

| Slash command | Drives | One-shot | Interactive TUI |
|---|---|---|---|
| `/pi-own` | the [Pi](https://github.com/earendil-works/pi) CLI | `pi -p '...'` | `pi --tui-mode regular` (PTY) |
| `/gentle-shell-own` | the [gentle-shell](https://github.com/Gentleman-Programming/gentle-shell) launcher (Gentle Shell workspace for Pi) | `gentle-shell -p '...'` | `gentle-shell --tui-mode regular` (PTY) |

Adding the next one (e.g. `/agy-own`) is: new folder under `skills/`, new spec
under `specs/`, done. The installer picks it up automatically.

## How it works

Typing `/pi-own <task>` (or `/gentle-shell-own <task>`) does **not** magically
run the CLI. Hermes registers every skill under `~/.hermes/skills/` as a
slash command; invoking it injects that skill's `SKILL.md` into the agent's
context. The agent then drives the real binary through its terminal tool —
one-shot by default, PTY/TUI for iterative work, background for long tasks —
and reports the result.

Both skills are **provider-agnostic**: bare delegation, no `--model`, no
preflight, no key handling. The CLI (or its home) resolves whatever provider
and model you configured.

## Requirements

- [Hermes Agent](https://hermes-agent.nousresearch.com/docs) with skills support
- For `/pi-own`: [Pi](https://github.com/earendil-works/pi) CLI installed and
  working (tested against v1.1.0)
- For `/gentle-shell-own`: [gentle-shell](https://github.com/Gentleman-Programming/gentle-shell)
  (npm package [`gentle-pi`](https://www.npmjs.com/package/gentle-pi))
  installed and working (`npm i -g gentle-pi`)

## Install

```bash
git clone https://github.com/albertopo94/pi-gentleShell-hermes-skill.git
cd pi-gentleShell-hermes-skill
./install.sh
```

This installs every skill under `skills/` to
`~/.hermes/skills/autonomous-ai-agents/<name>/` (backing up any existing
version). Verify:

```bash
hermes skills list | grep -e pi-own -e gentle-shell-own
```

Then use them:

```
/pi-own refactor the auth module to JWT and add tests
/gentle-shell-own build the OAuth refresh flow and verify it
```

## Update

`git pull && ./install.sh` — the installer diffs and backs up before replacing.

## Repository layout

| Path | Purpose |
|------|---------|
| `skills/<name>/SKILL.md` | The products. What gets installed. |
| `specs/<name>.md` | Per-skill product specs (verified-before-written). |
| `install.sh` | Installer (copies every skill, with backup). |

## Security notes

- The skills never ask for an API key and instruct the agent to never print
  credentials or provider configs into replies, logs, or memory.
- If a local gateway/proxy is used and goes down, the agent tells you — it
  never starts or repairs background daemons autonomously.
- `/gentle-shell-own` never enables YOLO or changes permission state
  autonomously; destructive confirmations are relayed to you, never
  auto-answered.
- User-level skills in `~/.hermes/skills/` are user-trusted by Hermes. Keep it
  MIT and local-friendly; removal of any skill is a folder delete.

## Uninstall

```bash
rm -rf ~/.hermes/skills/autonomous-ai-agents/pi-own
rm -rf ~/.hermes/skills/autonomous-ai-agents/gentle-shell-own
```

No other state to clean — nothing else references them.

## License

MIT
