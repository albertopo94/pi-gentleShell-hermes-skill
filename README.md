# pi-own — a custom Hermes skill for delegating coding to the Pi CLI

`/pi-own <task>` in a [Hermes](https://hermes-agent.nousresearch.com) chat
delegates the task to the [Pi](https://github.com/badlogic/pi-mono) coding CLI,
the same way the bundled `/claude-code`, `/codex` and `/opencode` skills drive
their CLIs. It is a plain `SKILL.md` (an operation manual injected into the
agent context) — no integration code, no daemon, no network dependency beyond
your own setup.

The `-own` suffix namespaces it as a **user-maintained** skill so it never
collides with a potential future official `/pi` skill from Nous. Both can
coexist; to retire this one, delete the skill folder.

## How it works

Typing `/pi-own <task>` does **not** magically run Pi. Hermes registers every
skill under `~/.hermes/skills/` as a slash command; invoking it injects this
skill's `SKILL.md` into the agent's context. The agent then drives the real
`pi` CLI through its terminal tool — one-shot (`pi -p`) by default, PTY/TUI for
iterative work, background for long tasks — and reports the result.

## Requirements

- [Hermes Agent](https://hermes-agent.nousresearch.com/docs) with skills support
- Pi CLI installed, configured, and working (tested against v1.1.0)
- Any provider/model configured in Pi — the skill delegates directly and
  lets Pi resolve its own settings natively.

## Install

```bash
git clone https://github.com/albertopo94/pi-own-hermes-skill.git
cd pi-own-hermes-skill
./install.sh
```

This copies `skill/SKILL.md` to
`~/.hermes/skills/autonomous-ai-agents/pi-own/SKILL.md` (backing up any
existing version). Verify:

```bash
hermes skills list | grep pi-own
```

Then use it:

```
/pi-own refactor the auth module to JWT and add tests
```

## Update

`git pull && ./install.sh` — the installer diffs and backs up before replacing.

## Repository layout

| Path | Purpose |
|------|---------|
| `skill/SKILL.md` | The product. What gets installed. |
| `SPEC.md` | Product spec: origin, design decisions, verified Pi facts, pitfalls, acceptance criteria. |
| `install.sh` | Installer (copy + backup). |

## Security notes

- The skill never asks for an API key and instructs the agent to never print
  credentials or provider configs into replies, logs, or memory.
- If a local gateway/proxy is used and goes down, the skill instructs the agent
  to tell you so, never to start or repair background daemons autonomously.
- User-level skills in `~/.hermes/skills/` are user-trusted by Hermes. Keep it
  MIT and local-friendly; nothing references the skill name in config, so
  removal is a folder delete.

## Uninstall

```bash
rm -rf ~/.hermes/skills/autonomous-ai-agents/pi-own
```

No other state to clean — nothing else references it.

## License

MIT
