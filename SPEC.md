# pi-own — Custom Hermes Skill for Delegating to the Pi CLI

> ⚠️ **SUPERSEDED (2026-10-11) — historical record.** This document describes the
> original design (agy-bridge preflight, pinned `--model agy/...`). After live
> testing the shipped product became fully provider-agnostic: bare `pi -p`, no
> preflight, no model pinning, TUI findings encoded as pitfalls. The contract of
> the product is `skill/SKILL.md`; the current spec is `SPEC-v3.md`. See commits
> `126b87e` → `f7db52b`. Sections §6 (auth model), §8/§9 (model pinning), §9
> pitfall 1, and §11 acceptance criteria 3/5 no longer reflect reality.

Product spec for a custom, locally-installed Hermes skill (`/pi-own`) that lets the user
delegate coding tasks to the Pi CLI from the Hermes chat, emulating the behavior of the
bundled delegation skills (`/claude-code`, `/codex`, `/opencode`).

---

## 1. Origin: where the idea comes from

Hermes ships bundled delegation skills under `autonomous-ai-agents/` for three coding CLIs:

| Skill | CLI | One-shot flag | Interactive mode |
|-------|-----|---------------|------------------|
| `claude-code` | `claude` | `claude -p "task"` | TUI via PTY/tmux |
| `codex` | `codex` | `codex exec "task"` (pty=true) | TUI via PTY/tmux |
| `opencode` | `opencode` | `opencode run "task"` | TUI via PTY/tmux |

Pattern: typing `/claude-code <task>` in the Hermes chat does NOT magically run the CLI.
The slash command merely injects the skill's SKILL.md (an operation manual) into the agent
context. The agent then drives the real CLI through the `terminal` tool, choosing the right
mode, flags, workdir, and timeout, and reports the result back.

**Gap:** the Pi CLI (v1.1.0, installed at `~/Library/pnpm/pi`) has **no bundled delegation
skill** in Hermes. Pi exposes the same delegation surface as the others:

- `pi -p / --print` — non-interactive one-shot (equivalent to `claude -p`)
- `pi` bare — interactive TUI (equivalent to `claude` REPL / `codex`)

So the product is: build the missing skill ourselves, following the exact precedent.

## 2. What it emulates

The user experience of `/claude-code`:

```
/pi-own refactor the auth module to JWT and add tests
```

→ Hermes agent loads the manual → runs `pi -p '<task>'` with the correct workdir/flags →
returns a summary of what Pi did. No manual CLI invocation by the user.

## 3. Why the name `pi-own` (naming convention)

- Hermes auto-registers every skill under `~/.hermes/skills/` as a slash command using the
  skill's `name` field. A future official `pi` skill from Nous would register as `/pi`.
- The `-own` suffix namespaces custom, self-maintained skills so they **never collide** with
  a future official one. If the official `/pi` ever ships, `/pi-own` keeps working and can
  be deleted at the user's discretion.
- **Future convention (if more are added later):** `<cli>-own` — e.g. `/agy-own` for the
  Antigravity CLI. Deliberately NOT a suite or shared framework: each CLI has genuinely
  different auth, sandboxing, and flag semantics; the "common part" is just copy the
  structure of an existing skill. The maintainers keep claude-code/codex/opencode separate
  for the same reason. The `-own` suffix plus this doc is the only coordination needed.

## 4. Target location and registration

```
~/.hermes/skills/autonomous-ai-agents/pi-own/SKILL.md
```

- Frontmatter `name: pi-own` → registers `/pi-own` automatically (case-insensitive).
- Placed in the same category as the other delegation skills for consistency.
- No hub install, no network: fully local, MIT-licensed, user-owned.

## 5. The precedent base (comparison set)

Structure to emulate, taken from the three bundled skills:

- **`claude-code`** (v2.2.0, 745 lines) — the most complete. Sections: prerequisites,
  two orchestration modes (print vs PTY), dialog handling, print-mode deep dive (JSON
  output, sessions, bare mode), full CLI flag reference, settings/memory hierarchy,
  subagents, hooks, MCP, monitoring, env vars, cost tips, pitfalls, agent rules.
- **`opencode`** (v1.2.0, 219 lines) — medium. Binary resolution, one-shot `run`,
  interactive TUI, background mode, parallel worktrees.
- **`codex`** (v1.0.0, 149 lines) — minimal. One-shot `exec`, background mode, key flags,
  gateway sandbox caveat, parallel worktrees, 7 rules.

**Recommended size for `pi-own`:** the middle tier (opencode/codex level, ~150–250 lines).
Pi's surface is close to Codex's complexity. Do not bloat toward claude-code's 745 lines;
include sections only where Pi actually differs or has verified gotchas.

Suggested section list:

1. Frontmatter (name, description, version 1.0.0, author, license MIT, platforms
   [linux, macos, windows], metadata.hermes.tags, related_skills: [claude-code, codex, opencode])
2. When to use / prerequisites
3. **Auth model (the custom part — see §6)**
4. One-shot mode (`pi -p`) — preferred
5. Interactive TUI mode (pty / tmux)
6. Key flags reference (verified table — see §8)
7. Session continuation (`-c`, `--resume`, `--session-id`)
8. Background mode for long tasks
9. Pitfalls & gotchas (verified on this machine — see §9)
10. Rules for the Hermes agent (max-turns-equivalents, workdir always, report results,
    clean up, don't persist secrets)

## 6. Auth model — the key difference from the bundled skills (CORRECTED v2)

Claude Code / Codex / OpenCode persist auth in well-known locations (`~/.claude`,
`~/.codex/auth.json`, `opencode auth login`). Pi on this machine uses a different,
**user-built** mechanism: the **agy-model-bridge** gateway (the user's own project,
`~/Reguero/Proyectos/agy-model-bridge`).

### The real daily flow (user-described, verified end-to-end on 2026-10-09)

```
agy-bridge setup-pi     # writes ~/.pi/agent/models.json with provider "agy"
pi                      # Pi reads models.json automatically — no key handling
```

Verified facts:

1. `agy-bridge` is a **local OpenAI-compatible gateway** (Antigravity Model Bridge)
   listening on `http://127.0.0.1:24980` (default port). It proxies to Google/Antigravity
   models using the user's `agy` auth. The bridge persists its state in `~/.agy-bridge/`
   (`api_key`, `bridge.pid`, `bridge.lock`, `bridge.log`).
2. `agy-bridge setup-pi` writes `~/.pi/agent/models.json` registering a custom provider
   `agy` → `baseUrl: http://127.0.0.1:24980/v1`, `api: openai-completions`, `apiKey`: the
   **local bridge key** (NOT a real upstream key — credentials never land in Pi's config),
   plus a model catalog (e.g. `agy/gemini-3.8-flash-high`). Optional `--set-default`
   makes it the default provider in Pi's `settings.json`.
3. **No per-invocation key injection needed.** Real test: agent ran
   `pi -p "responde solo: OK" --no-session --no-tools --model agy/gemini-3.8-flash-high`
   → Pi replied `OK`. That is the whole delegation contract.
4. Consequence for the skill: it never asks the user for a key. Its auth section reduces
   to a two-line readiness preflight (below).

### Readiness preflight the skill must encode (idempotent, safe to run every session)

1. **Gateway up?** `curl -s -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:24980/`
   → expect `200`. If not: the bridge daemon is not running → tell the user to start
   `agy-bridge` (their usual launch), do NOT attempt to start the daemon autonomously
   (it needs the user's Antigravity auth).
2. **Pi configured?** `~/.pi/agent/models.json` exists and contains the `agy` provider.
   If missing → run `agy-bridge setup-pi` (idempotent; verified safe, creates backups).
3. **Delegate** with `pi -p ... --model agy/<supported-model>`.

### What this changes vs. the v1 spec (honesty note)

The v1 draft claimed the agent must ask the user for a key per session and inject it via
env. **That was wrong**: it was inferred before the agy-bridge flow was known. No key
ever appears in conversation, command lines, or logs — the only credential in Pi's config
is a local loopback key for the bridge. The security story is actually *stronger* than
the bundled skills (no upstream credentials in client configs at all). Keep the rule that
the agent must never print the contents of `models.json`'s `apiKey` or `~/.agy-bridge/api_key`
in replies or memory.

## 7. Product decisions already settled

- Single skill, not a suite (see §3).
- Name: `pi-own`.
- Location: local `~/.hermes/skills/autonomous-ai-agents/pi-own/`.
- Auth: agy-model-bridge flow (see §6) — no per-session key handling; skill does a
  gateway+config preflight instead.
- Emulate the opencode/codex middle tier in size and structure, not claude-code's depth.

## 8. Verified Pi CLI facts (v1.1.0, tested 2026-10-09 on this machine)

From `pi --help` (do not invent flags; re-verify with `pi --help` before relying on a
specific one after any `pi update`):

| Flag | Effect |
|------|--------|
| `-p, --print` | Non-interactive: process prompt and exit (one-shot mode) |
| `--model <pattern> [--provider <name>]` | Model selection, pattern or `provider/id` with optional `:<thinking>` |
| `--api-key <key>` | API key for the run (env injection also works) |
| `--no-session` | Ephemeral run, nothing saved (preferred for CI-style one-shots) |
| `-c, --continue` | Continue the previous session |
| `-r, --resume <id>` / `--session <path\|id>` / `--session-id <id>` | Session control |
| `--fork <path\|id>` | Fork a session |
| `--thinking <level>` | off / minimal / low / medium / high / xhigh / max |
| `-t, --tools <list>` / `-nt` / `-xt <list>` | Tool allowlist / disable all / denylist |
| `--system-prompt` / `--append-system-prompt` | Replace / extend the system prompt |
| `-e, --extension` / `--no-extensions` | Extension loading |
| `--no-mcp` | Disable MCP |
| `--skill` / `--no-skills` | Skill loading |
| `-a, --approve` / `-na` | Trust / ignore project-local files |
| `--mode <text\|json\|rpc>` | Output mode (text default) |
| `--tui-mode <fullscreen\|regular>` | TUI rendering |
| `--export <file>` | Export session to HTML |
| `--no-context-files` | Skip AGENTS.md / CLAUDE.md discovery |

Other verified commands: `pi auth check --provider/--model`, `pi config` (TUI),
`pi install/remove/update/list`, `pi mcp`, `pi <command> --help`.

Unlike Codex, Pi does **not** refuse to run outside a git repository (not stated in help;
verify on first real use and document the finding in the skill).

## 9. Environment quirks verified on this machine (must go in the skill's pitfalls)

1. **Stale model pattern warning:** Pi prints `Warning: No models match pattern
   "google/gemini-3.7-flash"` because `~/.pi/agent/settings.json` has
   `defaultModel: gemini-3.5-flash` while `enabledModels` lists `gemini-3.7-flash`.
   → Always pass `--model` explicitly in delegated invocations; do not rely on defaults.
2. **Harmless extension warning:** `gentle-pi` package's `quiet-tools.ts` registers a
   `codemode` tool, shadowing the built-in one. Cosmetic; optionally suppress with
   `--no-extensions` when the builtin codemode matters.
3. **Pi auth lives in `~/.pi/agent/models.json` (agy provider), NOT in `settings.json`
   or `auth.json`** (both of which are key-free). If `models.json` is missing, run
   `agy-bridge setup-pi` to regenerate it. Note: the file can legitimately disappear
   (e.g. `agy-bridge` restore/uninstall) — always preflight, never assume persistence.
4. **The `GEMINI_API_KEY` in `~/.zshrc` is irrelevant to this flow** (and is currently
   invalid anyway). Do not use it; the bridge owns upstream auth.
5. **`pi --list-models` hung >30s** in non-interactive use — do not use it as a discovery
   step; read the model catalog from `~/.pi/agent/models.json` (`providers.agy.models[].id`)
   or use the known-good `agy/gemini-3.8-flash-high`.
6. Pi's TUI is fullscreen by default (`tuiMode: fullscreen` in settings) — for interactive
   delegation via PTY/tmux, `--tui-mode regular` makes `capture-pane` output far more
   useful.

## 10. Risks & maintenance

- **CLI drift:** Pi is fast-moving (user's own package list pins `gentle-engram@0.1.14`
  next to it, and extensions update independently). Mitigation: the skill's first rule is
  "when in doubt, `pi --help`"; pin the tested version (1.1.0) in the skill header.
- **Bridge coupling:** the flow depends on the agy-bridge daemon being up (user's own
  project, `agy-model-bridge` engram project). If the daemon is down the skill must tell
  the user, not start/repair the daemon autonomously. Bridge model IDs (e.g.
  `gemini-3.8-flash-high`) come from the bridge's catalog — if the bridge adds/renames
  models, re-read `models.json` rather than hardcoding.
- **Credential hygiene:** upstream creds never touch Pi's config (bridge owns them), but
  the local loopback key is still a secret — never print `models.json`'s `apiKey` field or
  `~/.agy-bridge/api_key` in replies, logs, or memory.
- **Official skill someday:** if Nous ships a `pi` skill, `/pi-own` is redundant; delete
  the folder, zero other changes needed (no config references the skill name).
- **No hub dependency:** keep it local and MIT so `hermes update` or skill scans can never
  break or remove it. (Note: project-level skills do get security-scanned by Hermes;
  user-level skills in `~/.hermes/skills/` are user-trusted by design.)

## 11. Acceptance criteria (when the product is "done")

1. `~/.hermes/skills/autonomous-ai-agents/pi-own/SKILL.md` exists, valid frontmatter,
   `name: pi-own`, passes `hermes skills list` (enabled).
2. `/pi-own` appears in the Hermes Desktop chat autocomplete.
3. `/pi-own <small task>` completes via `pi -p ... --model agy/<model>` and returns a real
   result (verified by actual execution, not by reading code). NOTE: on 2026-10-09 this
   exact call was already proven working end-to-end from the Hermes terminal
   (`pi -p "responde solo: OK" ... --model agy/gemini-3.8-flash-high` → `OK`).
4. No credential is printed or written by the flow (agent never cats `models.json`'s
   apiKey or `~/.agy-bridge/api_key` into replies, logs, or memory).
5. Preflight works when degraded: with the bridge daemon down, the skill reports the
   gateway check failing and asks the user to start `agy-bridge` — it does NOT attempt to
   start the daemon or ask for an API key.
6. The skill documents: one-shot mode, interactive PTY mode, session continuation,
   background/long-task mode, and the pitfalls from §9.

## 12. Out of scope (deliberately)

- Suite/framework for other `-own` skills (see §3 — just copy structure later if needed).
- Persisting the key anywhere (conflicts with the user's stated workflow).
- Modifying `~/.pi/agent/settings.json` model defaults (user's Pi setup is intentional).
- Antigravity (`/agy-own`) — future, same template, separate effort.

## 13. Parity with `/claude-code` — honest answer to "would it allow the same?"

**Short answer: the delegation *pattern* is the same; the CLI surface is not, and the auth
flow is fundamentally different.** A user typing `/pi-own <task>` gets the same *feeling*
(one-shot delegation + result summary, interactive PTY for multi-turn, session
continuation, background for long tasks, parallel worktrees) but cannot expect every
`claude -p` flag to have a Pi equivalent.

### Same (verified against `pi --help` v1.1.0)

| `/claude-code` capability | `/pi-own` equivalent | Notes |
|---|---|---|
| One-shot non-interactive | `pi -p "task"` | Preferred mode, same shape |
| Interactive TUI | `pi` bare, PTY via tmux | Same orchestration as codex |
| Session continuation | `-c`, `--resume`, `--session-id`, `--fork` | Pi has finer session control |
| Bounded execution | `--no-session` (ephemeral) | Closest to `claude --no-session-persistence` |
| Tool allowlist / denylist | `--tools`, `--exclude-tools` | Pi uses comma-separated names/patterns |
| System prompt override | `--system-prompt`, `--append-system-prompt` | Supports text or file contents |
| Extension control | `--extension`, `--no-extensions` | |
| Context file control | `--no-context-files` | Skips AGENTS.md / CLAUDE.md |
| Output modes | `--mode text/json/rpc` | `json` ≈ `claude --output-format json` (no `--json-schema` validation) |
| Thinking level control | `--thinking off/minimal/low/medium/high/xhigh/max` | Closest to `claude --effort` |
| Trust project-local files | `--approve` / `--no-approve` | Weaker than `--dangerously-skip-permissions` |
| Parallel worktrees | Same `git worktree` pattern | Skill documents it identically |

### Not the same (do not claim parity; document as gaps)

| `claude -p` capability | Pi equivalent | Status |
|---|---|---|
| `--max-turns` (agentic loop cap) | **none** | Mitigate: bounded prompt + `--no-session` + human review of result |
| `--max-budget-usd` (cost cap) | **none** | Mitigate: bounded prompt, report cost from `--mode json` |
| `--output-format json` + `--json-schema` | `--mode json` only, **no schema validation** | Use `--mode json` and validate manually |
| `--bare` (skip hooks/plugins/MCP/CLAUDE.md/OAuth) | `--no-extensions --no-mcp --no-skills --no-context-files --no-session` | Composable, but multi-flag; not a single `--bare` |
| `--dangerously-skip-permissions` | `--approve` only (trusts project-local files) | **Weaker.** Never auto-approve file writes; use narrow `--tools` instead |
| `--allowedTools` (whitelist with `Bash(git *)` patterns) | `--tools` (comma-separated names/patterns) | Similar, different syntax; Pi tool names differ from Claude's |
| `--from-pr <n>` (resume from GitHub PR) | **none** | |
| `--worktree` / `--tmux` (isolated worktree + tmux session) | **none** | Use plain `git worktree` + manual tmux (skill documents it) |
| `--fallback-model` (auto-fallback on overload) | **none** | |
| `--session-id <uuid>` | `--session-id <id>` | Same shape |
| `--append-system-prompt-file` | `--append-system-prompt` accepts file contents | Same shape |

### The auth difference (resolved, not a blocker)

`/claude-code` works because `~/.claude` holds a persisted OAuth session. `/pi-own`
reaches the same zero-friction UX through a different door: the **agy-model-bridge**
gateway + `models.json` (§6, verified working). The skill asks the user for nothing —
its preflight is gateway-up + config-present, both machine-checkable. The delegation
experience is therefore at parity with `/claude-code`; what is genuinely weaker is the
Pi CLI's flag surface (tables above), not the auth story.

This is why the skill is named `pi-own` rather than `pi`: it encodes *this user's* custom
bridge flow, not a generic Pi install. If Nous ever ships an official `pi` skill, both can
coexist — the official one would assume ambient Pi auth; `/pi-own` knows about the bridge.
