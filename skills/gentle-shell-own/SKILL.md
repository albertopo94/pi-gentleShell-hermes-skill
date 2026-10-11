---
name: gentle-shell-own
description: "Delegate coding to the gentle-shell (Pi + Gentle Shell workspace) from Hermes chat."
version: 1.0.0
author: albertopo94 (user-owned, mirrors bundled claude-code/codex/opencode pattern)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Pi, Gentle-Shell, Delegation, ODD, Code-Review, Refactoring]
    related_skills: [claude-code, codex, opencode, pi-own]
---

# Gentle Shell CLI (user-owned delegation skill)

Delegate coding tasks to **gentle-shell** — the Gentle Shell workspace for Pi —
via the Hermes terminal. This is a **custom, user-maintained** skill (hence
`-own`): `/gentle-shell-own <task>` runs the task through whatever gentle-shell
home and provider the user has configured. Provider-agnostic by design: the
skill never inspects, requires, or mentions providers.

Tested live 2026-10-11 against gentle-pi v4.0.0. When in doubt, run
`gentle-shell --help` (or the forwarded `pi <cmd> --help`) — do not invent flags.

## How gentle-shell differs from plain pi

- The launcher `gentle-shell` opens Pi **with the Gentle Shell package loaded**
  and forwards every other argument to Pi unchanged.
- Default home is **isolated** at `~/.gentle-shell/agent` (its own sign-ins,
  models, sessions). `--link` reuses the user's `~/.pi/agent` instead.
  Check with `gentle-shell home` (read-only).
- The TUI adds workspace features the agent may drive or leave to the user:
  ODD workflow, `/gentle:*` commands, `alt+g` (Gentle Changes), `alt+a`
  (Gentle Agents), `/gentle:yolo` (OFF by default — never enable autonomously).

## When to use

- User explicitly asks for gentle-shell (`/gentle-shell-own <task>`)
- They want the Gentle Shell workspace (ODD, changes view, subagent cards)
  rather than plain Pi delegation (that is what `/pi-own` is for)

## One-Shot Tasks (preferred)

```
terminal(command="gentle-shell -p 'Add dark mode toggle to settings' --no-session", workdir="~/project", timeout=600)
```

Flags are Pi's flags, forwarded verbatim: `--no-session`, `--no-tools`,
`--thinking`, `--mode json`, `-t/-nt/-xt`, `--append-system-prompt`, etc.
Verified working: `gentle-shell -p 'responde solo: GS_OK' --no-session --no-tools`.

## Interactive workspace sessions (background PTY)

For iterative work or when the user wants to lead the workspace:

```
terminal(command="gentle-shell --tui-mode regular", workdir="~/project", background=true, pty=true)
# Returns session_id

process(action="submit", session_id="<id>", data="Implement OAuth refresh flow and add tests")
process(action="write",  session_id="<id>", data="\r")   # CRITICAL: submit alone does NOT dispatch
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Exit
process(action="write", session_id="<id>", data="\x03")   # or process(action="kill", ...)
```

Verified working 2026-10-11: `submit` + `write "\r"` → `GS_PTY_OK` in the TUI.
Same dispatch rule as every other agent TUI on this machine. If the TUI raises
a confirmation (e.g. a destructive-operation prompt), read the prompt from
`log`, ask the user, then answer via `submit` + `write "\r"`. Never answer a
destructive confirmation autonomously.

## Forwarded management commands (all run against the resolved home)

| Command | Effect |
|---------|--------|
| `gentle-shell home [link\|isolated\|<path>]` | Show or persist effective home mode |
| `gentle-shell setup [--dry-run]` | Provision companion packages into the home |
| `gentle-shell install/npm/remove/list/update/config/auth ...` | Pi's own commands, forwarded verbatim |
| `gentle-shell --version` | Launcher, Pi, and home versions |

Prefer `--dry-run` and read-only forms when diagnosing. These commands
provision the **gentle-shell home**, never the user's `~/.pi` — unless
`--link` is active, in which case ask the user first.

## Rules for the Hermes agent

0. **Explicit `/gentle-shell-own` invocation means DELEGATE — always**, even
   for trivial tasks (same rule as pi-own; the slash is the decision).
1. **Delegate bare** — no provider, no `--model`, no key. The gentle-shell home
   resolves its own defaults exactly like the user's own usage.
2. **Default to the isolated home** (the launcher's default). Do not pass
   `--link` or `--home` unless the user asks — they change which config store
   is touched.
3. **Always set `workdir`**; scope one run per workdir; worktrees as repo
   siblings, never under `/tmp`.
4. **Never enable YOLO or change permission state** (`/gentle:yolo enable` and
   friends) autonomously — session permissions are the user's call, and
   destructive confirmations must be relayed to the user, never auto-answered.
5. **Never print secrets or config contents** (apiKey fields, auth.json,
   models.json) into replies, logs, or memory. Never ask the user for a key.
6. **Troubleshoot on failure only** — no preflight on the happy path.
7. For long tasks, background + `process(poll/log)`; report progress from logs.
8. **Report concrete outcomes**: files changed, tests run, remaining risks —
   verify with `git diff` and targeted tests before declaring done.
9. Clean up: exit TUI sessions (Ctrl+C / kill), remove worktrees when merged.
10. If behavior drifts after `gentle-shell update` / `pi update`, re-run
    `gentle-shell --help` and `pi --help` and update this skill.

## Pitfalls (verified on this machine)

1. **`submit` does not dispatch** — always follow with `write "\r"`; symptom is
   the prompt sitting in the input box with no working spinner.
2. **Always `--tui-mode regular`** for PTY sessions — fullscreen makes capture
   output useless.
3. **Skill-registry noise in TUI logs** (e.g. "name contains invalid characters"
   warnings, "Skill registry refreshed (N skills)") is cosmetic.
4. **One-shot does not need pty**; the TUI does.
5. **Do NOT pass `--model`** unless the user asks — same rule as pi-own.

## Verification (smoke test)

```
terminal(command="gentle-shell -p 'responde solo: OK' --no-session --no-tools")
```

Success: output contains `OK`, exits cleanly, no provider/auth errors.
(Proven working 2026-10-11 on this machine: `GS_OK`.)
