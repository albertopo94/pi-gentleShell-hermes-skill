# pi-own — Product Spec v3 (current)

The contract for the shipped product, rewritten 2026-10-11 after live end-to-end
verification. Supersedes the v1 design in `SPEC.md` (kept as historical record).
The operational contract the agent actually follows is `skill/SKILL.md`; this
document is the product-level spec: what it promises, why, and what was proven.

## 1. Product

A local, user-owned Hermes skill (`/pi-own <task>`) that delegates coding tasks
to the Pi CLI from a Hermes chat, mirroring the bundled `/claude-code`,
`/codex`, `/opencode` skills. Slash invocation injects `skill/SKILL.md` into the
agent context; the agent drives the real `pi` binary through its terminal tool.

Naming: `-own` namespaces it as user-maintained so a future official `/pi` skill
can coexist. Uninstall = delete the folder; nothing references the name.

## 2. Core principle: provider-agnostic, zero-config

The agent knows **nothing** about providers, models, gateways, or keys.
Delegation is bare `pi -p "<task>"` — Pi resolves whatever the user configured
(`~/.pi/agent/models.json`), exactly like the user running `pi` by hand.

**Why (learned the hard way, v1→v2→v3):**
- v1 assumed per-session API keys → wrong (users have ambient setups).
- v2 hardcoded this machine's agy-model-bridge gateway + `--model agy/...` →
  worked, but coupled a delegation skill to one machine's topology. Pi can have
  N providers (this machine runs agy-bridge on :24980 and FreeLLMAPI on :31415
  simultaneously); neither Hermes nor the skill should care.
- v3 (current): the skill delegates and forgets the provider exists. Verified:
  `pi -p` with no `--model` works against the user's default (`freellmapi/auto`).

The bundled skills validate this: none of them mention providers in the
delegation path; their CLIs have a single auth store shared by print and TUI.

## 3. Delegation modes (both proven live, not inferred)

| Mode | Command | Pty | Status |
|---|---|---|---|
| One-shot | `pi -p "<task>" --no-session` | no | ✅ proven (`OK`, `FINAL_OK`, install.sh review, minesweeper) |
| Background long task | `terminal(background=true)` + `process(poll/log)` | no | ✅ proven (~5 min minesweeper run) |
| Interactive TUI | `pi --tui-mode regular` + submit + `write "\r"` | **yes** | ✅ proven full cycle (`PTY_OK`, 2026-10-11) |

### The `\r` rule (verified on this machine, generic to agent TUIs)

`process(submit)` types text into the TUI input box but does **not** dispatch it.
Every send must be followed by `process(write, "\r")`. Confirmed identically on
Pi's TUI and Claude Code's TUI. Symptom if missed: prompt text sits in the input
box with no working spinner.

### Per-mode default-model divergence (pitfall, observed and resolved)

Print mode and the TUI can resolve **different** default models. A stale TUI
default once sent requests to Google with an invalid `GEMINI_API_KEY` (400)
while `pi -p` worked fine. Resolution belongs to the user (`pi config`);
the agent's only allowed `--model` usage is launching the TUI with an explicit
model **after** this exact failure — troubleshooting, never happy path.

## 4. Hard rules (agent behavior)

1. Explicit `/pi-own` ⇒ delegate, always — even for trivial tasks. The user's
   slash invocation IS the decision. (Bundled skills leave "when to delegate" to
   agent judgment; ours does not, on purpose: `/pi-own` promises execution.)
   Root cause found 2026-10-11: agent answered a trivial `/pi-own` task itself
   via `read_file`, no `pi` executed. Caught in agent.log.
2. No provider/model/key inspection. No preflight on the happy path.
3. Troubleshooting only on failure; gateways are reported, never started or
   repaired autonomously.
4. Never print credentials or config contents (apiKeys, models.json) to
   replies/logs/memory. Never ask the user for a key.
5. Always `workdir`; one Pi run per workdir; worktrees as repo siblings, not
   under `/tmp`.
6. Report concrete outcomes (files, tests, risks) verified via `git diff`.
7. Pi moves fast: `pi --help` beats the flag table after any update.

## 5. Verified environment facts (2026-10-11)

- Pi CLI v1.1.0; `pi -p` and TUI both exit/work without a git repo (tested).
- Machine runs multiple OpenAI-compatible gateways (agy-bridge :24980,
  FreeLLMAPI :31415 as desktop app `FreeLLMAPI.app`). `lsof`/`ps` before
  attributing any local port to any product — an earlier session wrongly
  guessed this from log fragments.
- `pi --list-models` hangs non-interactively (>30s); never use it.
- `gentle-pi` codemode shadow warning and stale-model warnings are cosmetic.
- TUI defaults to fullscreen → always `--tui-mode regular` under PTY.
- `pi config`/`settings.json`/`~/.zshrc` are the user's to edit — never the
  agent's, even as a "fix".

## 6. Acceptance criteria — status

| # | Criterion | Status |
|---|---|---|
| 1 | Skill installed, valid frontmatter, `hermes skills list` enabled | ✅ verified |
| 2 | `/pi-own` in Desktop chat | ✅ verified (invoked, loaded, followed) |
| 3 | Real delegation via `pi -p` returning a real result | ✅ verified (log-forensics: not just the chat's word) |
| 4 | No credential printed by the flow | ✅ held across all tests |
| 5 | Degraded path reports instead of autonomously fixing | ✅ verified (models.json-missing case, and bridge-down rule) |
| 6 | Documents one-shot, PTY, sessions, background, pitfalls | ✅ v3 content in SKILL.md |
| 7 | PTY full cycle (launch→send→provider reply→exit) | ✅ `PTY_OK` 2026-10-11, and Desktop-side Claude Code control test |

## 7. Out of scope (unchanged, still deliberate)

- Suites/frameworks for other `-own` skills (copy the structure if ever needed).
- Any mutation of the user's Pi/shell config by the agent.
- Antigravity `/agy-own` or other CLIs.
- Official-skill displacement: if Nous ships `/pi`, delete this folder.

## 8. Maintenance

- On Pi CLI updates: re-verify flags with `pi --help`; re-run the smoke test
  `pi -p 'responde solo: OK' --no-session --no-tools`.
- New pitfalls: only add what has been **observed on a real run**, with date.
- The README must stay in sync with §2–§3; SPEC.md stays frozen as history.
