# gentle-shell-own — Product Spec (current)

Written 2026-10-11 directly in v3 form (no v1/v2 baggage): the design rule of
this spec is *everything here was verified live before being written down*,
following the pi-own lessons (github.com/albertopo94/pi-own-hermes-skill).

## 1. Product

A local, user-owned Hermes skill (`/gentle-shell-own <task>`) that delegates
coding tasks to the **gentle-shell** launcher (Gentle Shell workspace for Pi,
package `gentle-pi`) from a Hermes chat — the fourth member of the user's
`-own` delegation family alongside `/pi-own`, mirroring bundled
`/claude-code`, `/codex`, `/opencode`.

Slash invocation injects `skills/gentle-shell-own/SKILL.md` into the agent context; the agent
drives the real `gentle-shell` binary through its terminal tool.

## 2. Core principle: provider-agnostic + home-aware

Delegation is bare `gentle-shell -p "<task>"` — the launcher's resolved home
(default: isolated `~/.gentle-shell/agent`) resolves providers/models exactly
like the user's own terminal usage. The agent never inspects providers.

New vs pi-own: the launcher has **two homes** (isolated vs `--link` into
`~/.pi/agent`). The skill defaults to the launcher's default and treats
`--link`/`--home` as user-only knobs, because they change which config store
is touched.

## 3. Delegation modes (both proven live, 2026-10-11, gentle-pi v4.0.0)

| Mode | Command | Pty | Proof |
|---|---|---|---|
| One-shot | `gentle-shell -p "<task>" --no-session` | no | `GS_OK` |
| Interactive TUI | `gentle-shell --tui-mode regular` + submit + `write "\r"` | yes | `GS_PTY_OK` full cycle |

The `\r` dispatch rule (submit alone does not send) applies here too —
confirmed identical to plain Pi and Claude Code TUIs on this machine.

## 4. Hard rules (agent behavior)

1. Explicit `/gentle-shell-own` ⇒ delegate, always (Rule 0 of the family).
2. Bare delegation: no provider, no `--model`, no keys, no preflight.
3. Isolated home by default; `--link`/`--home` only on explicit user request.
4. **Never** enable `/gentle:yolo` or alter permission state autonomously;
   destructive confirmations relay to the user, never auto-answered.
5. Never print credentials/config contents; never ask for keys.
6. Report concrete outcomes verified via `git diff`.
7. Re-verify flags with `gentle-shell --help` after updates.

## 5. Verified environment facts (2026-10-11)

- `gentle-shell` at `~/.local/bin/gentle-shell`, home mode `isolated`,
  provisioned 2026-10-02 (gentleAi/gentlePi 4.0.0).
- Isolated home already carries the user's providers (freellmapi default,
  agy bridge) — the launcher's home is a full Pi home, not a sandbox.
- TUI emits cosmetic skill-registry noise (`name contains invalid characters`,
  `Skill registry refreshed`) — harmless.
- Gentle Shell's `/gentle:jobs`, `alt+g` changes view, ODD tracking etc. are
  user-facing workspace features; the agent drives only the prompt channel.

## 6. Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Skill installed, enabled in `hermes skills list` | ✅ verified 2026-10-11 |
| 2 | `/gentle-shell-own` in Desktop chat autocomplete | ⏳ user check |
| 3 | Real one-shot delegation returns real result | ✅ `GS_OK` |
| 4 | Real PTY cycle (launch→dispatch→reply) | ✅ `GS_PTY_OK` |
| 5 | No credential printed by the flow | ✅ held |
| 6 | Documents one-shot, PTY, homes, pitfalls, rules | ✅ SKILL.md |

## 7. Out of scope

- Managing the gentle-shell home, provisioning, or upgrades.
- Driving `/gentle:*` workspace commands beyond relaying user intent.
- Official-skill displacement: if an official skill ships, delete this folder.
