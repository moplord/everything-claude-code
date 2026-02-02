# Hooks / Plugins System (OpenCode)

OpenCode uses a **plugin system** instead of Claude Code hooks.
This repo implements hook-equivalents in `.opencode/plugins/`.

## Where It Lives

- Plugins: `.opencode/plugins/*.js`
- Config/permissions: `opencode.jsonc` (project-level OpenCode config)

## Implemented Hook-Equivalents (This Repo)

- `.opencode/plugins/claude-hooks-parity.js`
  - Dev server tmux enforcement (blocks `npm run dev`-style commands outside tmux)
  - tmux reminder for long-running commands
  - reminder before `git push`
  - blocks creation of new random `.md/.txt` files (repo hygiene)
  - warns when `console.log` appears in edited JS/TS files (via `file.edited`)
  - logs PR URL after `gh pr create` (via `command.executed`)

- `.opencode/plugins/legacy-session-and-compact.js`
  - session continuity note file under `.opencode/sessions/`
  - strategic compaction suggestions (tool-call counter under `.opencode/state/`)
  - injects session notes on `experimental.session.compacting` so compaction keeps continuity

- `.opencode/plugins/codex-safety.js`
  - blocks obviously destructive shell commands (defense-in-depth)

## Permissions (OpenCode)

OpenCode permission gating is configured in `opencode.jsonc` under `"permission"`.
This repo ports Codex-style shell policy into `"permission.bash"` (allow safe reads, ask for remote, deny destructive).

## Environment Toggles

In `.opencode/plugins/claude-hooks-parity.js` you can disable behaviors by setting env vars to `0`:

- `OPENCODE_TMUX_ENFORCE_DEV=0`
- `OPENCODE_TMUX_WARN_LONG=0`
- `OPENCODE_BLOCK_RANDOM_DOCS=0`
- `OPENCODE_WARN_CONSOLE_LOG=0`
