# CLAUDE.md - Claude Code Project Adapter (v7)

@AGENTS.md

## Claude Code

The shared project rules are imported from `AGENTS.md` above. Keep project-wide rules there so Codex, Claude Code, and other agents read one source; keep only Claude Code-specific guidance in this file.

- RD Skills (`rd-*`) come from the project's `.claude/skills/` or from the Claude account as `anthropic-skills:rd-*`; keep one source, and do not edit account copies under `~/.claude/skills/synced/`, which sync overwrites. Claude may select them from their descriptions; invoke one explicitly with `/rd-*` when needed. `rd-delivery` follows the request-content rule in `AGENTS.md`.
- `.claude/settings.json` denies common secret-file reads and asks before commit, push, tag, publish, delete, and uncommitted-work-discarding Git commands. These rules are guardrails, not a complete security boundary; prefer settings, permissions, or hooks over written reminders for critical prohibitions.
- Do not paste Codex-only `config.toml`, Codex hooks, or Cursor `.mdc` syntax into Claude Code files. Translate behavior to Claude Code's native carriers.
- Put approved, stable Claude Code-specific conventions here; put project-wide conventions in `AGENTS.md`.
