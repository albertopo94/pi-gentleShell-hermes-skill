---
name: pi-own
description: "Delegate coding to the Pi CLI via the agy-model-bridge gateway (features, refactors, reviews)."
version: 1.0.0
author: albertopo94 (user-owned, mirrors bundled claude-code/codex/opencode pattern)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Pi, Delegation, agy-bridge, Code-Review, Refactoring]
    related_skills: [claude-code, codex, opencode]
---

# Pi CLI (user-owned delegation skill)

Delegate coding tasks to the Pi CLI via the Hermes terminal. This is a
**custom, user-maintained** skill (hence `-own`): it encodes this machine's Pi
setup, which authenticates through the **agy-model-bridge** gateway
(a local OpenAI-compatible proxy; adapt or drop the auth section if your Pi
uses ambient provider auth instead), not through ambient Pi OAuth. If an
official `/pi` skill ever ships, the two can coexist; delete this folder to
retire it, nothing else references it.

Tested against Pi CLI **v1.1.0** (2026-10-09). Pi moves fast: when in doubt,
run `pi --help` before relying on a flag. Do not invent flags.

## When to use

- User explicitly asks to use Pi (`/pi-own <task>`)
- Delegating a feature, refactor, or review to Pi instead of Claude/Codex/OpenCode
- Long coding sessions with progress checks, or parallel worktree tasks

## Auth model — agy-model-bridge (the key difference)

Pi on this machine has **no upstream credentials anywhere in its config**. Auth
flow:

```
agy-bridge setup-pi   # writes ~/.pi/agent/models.json with provider "agy"
pi -p "..."           # Pi reads models.json automatically — no key handling
```

- `agy-bridge` is a local OpenAI-compatible gateway
  (`http://127.0.0.1:24980`) proxying to Google/Antigravity models using the
  user's `agy` auth. State lives in `~/.agy-bridge/`.
- `agy-bridge setup-pi` registers provider `agy` in
  `~/.pi/agent/models.json` (`baseUrl: http://127.0.0.1:24980/v1`,
  `api: openai-completions`, plus a model catalog). The `apiKey` in that file
  is a **local loopback key for the bridge**, not a real credential.
- **The skill NEVER asks the user for an API key** and NEVER prints the
  contents of `models.json`'s `apiKey` or `~/.agy-bridge/api_key` in replies,
  logs, or memory.

### Readiness preflight (run before first delegation each session; idempotent)

1. **Gateway up?**
   `terminal(command="curl -s -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:24980/")`
   → expect `200`. If not: tell the user to start `agy-bridge` themselves.
   Do NOT start or repair the daemon autonomously (it needs their Antigravity auth).
2. **Pi configured?** `~/.pi/agent/models.json` exists and contains the `agy`
   provider. If missing → run `agy-bridge setup-pi` (idempotent, makes backups).
   The file can legitimately disappear (bridge restore/uninstall) — always
   preflight, never assume persistence.
3. Then delegate with an explicit `--model agy/<model>` (see Pitfalls).

Model catalog: read `providers.agy.models[].id` from `~/.pi/agent/models.json`
(e.g. via `python3 -c` or `jq` on the models list only — never dump apiKey).
Known-good default: `agy/gemini-3.8-flash-high`. Do NOT use
`pi --list-models` — it hangs in non-interactive use (>30s verified).

## One-Shot Tasks (preferred)

```
terminal(command="pi -p 'Add dark mode toggle to settings' --no-session --model agy/gemini-3.8-flash-high", workdir="~/project", timeout=600)
```

Useful modifiers:
- `--no-session` — ephemeral run, nothing saved (preferred for CI-style one-shots)
- `--no-tools` — read/answer only (smoke tests)
- `-t <list>` / `-nt` / `-xt <list>` — tool allowlist / disable all / denylist
- `--mode json` — machine-readable output (no schema validation; parse manually)
- `--thinking <level>` — off/minimal/low/medium/high/xhigh/max
- `--no-extensions --no-mcp --no-skills --no-context-files --no-session` —
  composable "bare" equivalent
- `--append-system-prompt "<text>"` — extend the system prompt

Unlike Codex, Pi does **not** require a git repository (verify on first real
use in a scratch dir; do not assume, document the finding if it changes).

## Interactive TUI sessions (background)

For iterative work needing multiple exchanges:

```
terminal(command="pi --tui-mode regular --model agy/gemini-3.8-flash-high", workdir="~/project", background=true, pty=true)
# Returns session_id

process(action="submit", session_id="<id>", data="Implement OAuth refresh flow and add tests")
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")
process(action="submit", session_id="<id>", data="Now add token-expiry error handling")

# Exit
process(action="write", session_id="<id>", data="\x03")   # or process(action="kill", ...)
```

Always pass `--tui-mode regular` for PTY capture — the user's settings default
to `fullscreen`, which makes `capture-pane` output far less useful.

## Session continuation

| Flag | Effect |
|------|--------|
| `-c, --continue` | Continue the previous session |
| `-r, --resume <id>` | Resume a specific session |
| `--session <path\|id>` / `--session-id <id>` | Session control |
| `--fork <path\|id>` | Fork a session |

```
terminal(command="pi -c -p 'Now refactor the tests you wrote' --model agy/gemini-3.8-flash-high", workdir="~/project")
```

## Background mode for long one-shots

```
terminal(command="pi -p 'Refactor the auth module to JWT and add tests' --model agy/gemini-3.8-flash-high", workdir="~/project", background=true)
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")
```

## Parallel worktrees

```
terminal(command="git worktree add -b fix/issue-78 ../<repo>-worktrees/issue-78 main", workdir="~/project")
terminal(command="pi -p 'Fix issue #78: <description>. Commit when done.' --model agy/gemini-3.8-flash-high", workdir="../<repo>-worktrees/issue-78", background=true)
# ... monitor, push, PR, then: git worktree remove <path>
```

Place worktrees as siblings under the repo parent (CodeGraph-friendly); never under `/tmp`.

## Key flags reference (verified from `pi --help` v1.1.0)

| Flag | Effect |
|------|--------|
| `-p, --print` | Non-interactive one-shot, exits when done |
| `--model <pattern>` | Model selection; `provider/id`, optional `:<thinking>` |
| `--no-session` | Ephemeral run |
| `-c` / `-r <id>` / `--session` / `--session-id` / `--fork` | Session control |
| `--thinking <level>` | off…max |
| `-t / -nt / -xt` | Tools allowlist / none / denylist |
| `--system-prompt` / `--append-system-prompt` | Replace / extend system prompt |
| `-e / --no-extensions` | Extension control |
| `--no-mcp` / `--skill / --no-skills` | MCP / skill control |
| `-a, --approve` / `-na` | Trust / ignore project-local files |
| `--mode <text\|json\|rpc>` | Output mode |
| `--tui-mode <fullscreen\|regular>` | TUI rendering |
| `--export <file>` | Export session to HTML |
| `--no-context-files` | Skip AGENTS.md / CLAUDE.md discovery |

Other verified commands: `pi auth check --provider/--model`, `pi config` (TUI),
`pi install/remove/update/list`, `pi mcp`, `pi <command> --help`.

**No Pi equivalent (do not claim parity with claude-code):** `--max-turns`,
cost/budget cap, `--json-schema` validation, single `--bare` flag,
`--dangerously-skip-permissions` (`--approve` is weaker and only trusts
project-local files), `--from-pr`, built-in worktree/tmux. Mitigate with
bounded prompts + `--no-session` + human review of the diff.

## Pitfalls (verified on this machine)

1. **Always pass `--model` explicitly.** `~/.pi/agent/settings.json` has a
   stale default → Pi prints `Warning: No models match pattern...` otherwise.
   Never rely on Pi's default model.
2. **`gentle-pi` extension warning is harmless.** `quiet-tools.ts` registers a
   `codemode` tool shadowing the builtin. Cosmetic; add `--no-extensions` if
   the builtin codemode matters.
3. **Auth lives ONLY in `~/.pi/agent/models.json`** (agy provider) — not in
   `settings.json` or `auth.json` (both key-free). Missing file → run
   `agy-bridge setup-pi`.
4. **`GEMINI_API_KEY` in `~/.zshrc` is irrelevant** (and invalid). Never use it.
5. **`pi --list-models` hangs** in non-interactive use. Read the catalog from
   `models.json` instead.
6. **TUI defaults to fullscreen** — use `--tui-mode regular` for PTY sessions.
7. One-shot `pi -p` does NOT need pty; the interactive TUI does.

## Rules for the Hermes agent

1. **Preflight first** (gateway + models.json) once per session before delegating.
2. **Always set `workdir`** to the target repo; scope one Pi run per workdir.
3. **Always pass `--model agy/<model>`** — read the catalog if unsure of ids.
4. **Never print secrets**: `models.json` apiKey, `~/.agy-bridge/api_key`, or
   any credential into replies, logs, or memory. Never ask the user for a key.
5. **Bridge down → report, don't fix**: tell the user to start `agy-bridge`;
   do not launch or repair the daemon autonomously.
6. Prefer `pi -p` one-shots; interactive PTY only when iteration is needed.
7. For long tasks, background + `process(poll/log)`; report progress from logs.
8. **Report concrete outcomes**: files changed, tests run, remaining risks —
   verify with `git diff` and targeted tests before declaring done.
9. **No auto-approve of file writes beyond the task's workdir**; Pi has no
   permission-bypass flag — keep prompts narrow instead of widening trust.
10. Clean up: exit TUI sessions (Ctrl+C / kill), remove worktrees when merged.
11. If a flag errors or behavior drifts after a `pi update`, re-run `pi --help`
    and update this skill.

## Verification (smoke test)

```
terminal(command="pi -p 'responde solo: OK' --no-session --no-tools --model agy/gemini-3.8-flash-high")
```

Success: output contains `OK`, exits cleanly, no model/auth errors.
(Proven working end-to-end 2026-10-09 on this machine.)
