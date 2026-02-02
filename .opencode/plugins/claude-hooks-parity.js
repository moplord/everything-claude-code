// Compatibility plugin: ports key behaviors from legacy Claude Code hooks.json
// into OpenCode's plugin system, using safe defaults and env toggles.
//
// Env toggles (set to "0" to disable):
// - OPENCODE_TMUX_ENFORCE_DEV=1  (block dev servers outside tmux)
// - OPENCODE_TMUX_WARN_LONG=1    (warn for long-running commands outside tmux)
// - OPENCODE_BLOCK_RANDOM_DOCS=1 (block creating new random .md/.txt files)
// - OPENCODE_WARN_CONSOLE_LOG=1  (warn when console.log appears in edited JS/TS files)

import fs from "fs"
import path from "path"

function envOn(name, defaultOn = true) {
  const v = process.env[name]
  if (v == null) return defaultOn
  return v !== "0" && v.toLowerCase() !== "false"
}

function getArg(args, keys) {
  if (!args) return ""
  for (const k of keys) {
    const v = args[k]
    if (typeof v === "string" && v) return v
  }
  return ""
}

function isInTmux() {
  return Boolean(process.env.TMUX)
}

function normalizeSlash(p) {
  return String(p || "").replace(/\\/g, "/")
}

function isAllowedDocPath(p) {
  const norm = normalizeSlash(p)
  const base = path.posix.basename(norm)
  if (/(README|CLAUDE|AGENTS|CONTRIBUTING)\.md$/i.test(base)) return true
  // Always allow OpenCode config/instructions
  if (base === "opencode.json" || base === "opencode.jsonc") return true
  if (norm.startsWith(".opencode/")) return true
  if (norm.startsWith("legacy/")) return true
  if (norm.startsWith(".codex/")) return true
  return false
}

function isNewFile(p) {
  try {
    return !fs.existsSync(p)
  } catch {
    return false
  }
}

function readFileText(p) {
  try {
    return fs.readFileSync(p, "utf8")
  } catch {
    return ""
  }
}

function warn(msg) {
  // eslint-disable-next-line no-console
  console.warn(msg)
}

function die(msg) {
  throw new Error(msg)
}

export const ClaudeHooksParity = async () => {
  const enforceDevTmux = envOn("OPENCODE_TMUX_ENFORCE_DEV", true)
  const warnLongTmux = envOn("OPENCODE_TMUX_WARN_LONG", true)
  const blockRandomDocs = envOn("OPENCODE_BLOCK_RANDOM_DOCS", true)
  const warnConsoleLog = envOn("OPENCODE_WARN_CONSOLE_LOG", true)

  const devServerRe = /\b(npm\s+run\s+dev|pnpm(\s+run)?\s+dev|yarn\s+dev|bun\s+run\s+dev)\b/i
  const longCmdRe =
    /\b(npm\s+(install|test)\b|pnpm\s+(install|test)\b|yarn\s+(install|test)\b|bun\s+(install|test)\b|cargo\s+build\b|make\b|docker\b|pytest\b|vitest\b|playwright\b)\b/i

  function findNearestTsconfig(startFile) {
    try {
      let dir = path.dirname(startFile)
      for (;;) {
        const candidate = path.join(dir, "tsconfig.json")
        if (fs.existsSync(candidate)) return dir
        const parent = path.dirname(dir)
        if (parent === dir) return null
        dir = parent
      }
    } catch {
      return null
    }
  }

  return {
    event: async ({ event }) => {
      if (!event || !event.type) return

      const data = event.data || {}

      // Claude Code PostToolUse (Bash) equivalents via OpenCode events.
      if (event.type === "command.executed") {
        const cmd = data.command || data.cmd || ""
        const out = data.output || data.stdout || data.result || ""

        if (/\bgh\s+pr\s+create\b/i.test(cmd)) {
          const m = String(out).match(/https:\/\/github\.com\/[^/]+\/[^/]+\/pull\/\d+/)
          if (m) {
            const url = m[0]
            const repo = url.replace(/https:\/\/github\.com\/([^/]+\/[^/]+)\/pull\/\d+/, "$1")
            const pr = url.replace(/.*\/pull\/(\d+)/, "$1")
            warn(`[Hook] PR created: ${url}`)
            warn(`[Hook] To review: gh pr review ${pr} --repo ${repo}`)
          }
        }

        if (/\b(npm\s+run\s+build|pnpm\s+build|yarn\s+build)\b/i.test(cmd)) {
          warn("[Hook] Build completed (you can run further checks if needed).")
        }

        return
      }

      // Console log warnings via file.edited events.
      if (event.type === "file.edited") {
        if (!warnConsoleLog) return

        const file = data.file || {}
        const p = file.path || data.path || data.filePath || data.file_path || ""
        const norm = normalizeSlash(p)
        if (!norm) return
        if (!/\.(ts|tsx|js|jsx)$/i.test(norm)) return

        const abs = p && fs.existsSync(p) ? p : path.resolve(p)
        const content = readFileText(abs)
        if (!content) return
        if (!content.includes("console.log")) return

        const lines = content.split(/\r?\n/)
        const hits = []
        for (let i = 0; i < lines.length; i += 1) {
          if (lines[i].includes("console.log")) hits.push(`${i + 1}: ${lines[i].trim()}`)
          if (hits.length >= 5) break
        }
        warn(`[Hook] WARNING: console.log found in ${norm}`)
        for (const h of hits) warn(h)
        warn("[Hook] Remove console.log before committing.")
      }
    },

    "tool.execute.before": async ({ tool }, { args }) => {
      // Bash pre-tool hooks
      if (tool === "bash") {
        const cmd = getArg(args, ["command", "cmd", "script"])
        if (!cmd) return

        if (enforceDevTmux && devServerRe.test(cmd) && !isInTmux()) {
          die(
            "[Hook] BLOCKED: Dev server should run inside tmux for log access.\n" +
              "[Hook] Suggested:\n" +
              "  tmux new-session -d -s dev \"npm run dev\"\n" +
              "  tmux attach -t dev\n" +
              "[Hook] Disable with OPENCODE_TMUX_ENFORCE_DEV=0"
          )
        }

        if (warnLongTmux && longCmdRe.test(cmd) && !isInTmux()) {
          warn(
            "[Hook] Tip: Consider running long commands inside tmux for session persistence.\n" +
              "[Hook] Disable with OPENCODE_TMUX_WARN_LONG=0"
          )
        }

        if (/\bgit\s+push\b/i.test(cmd)) {
          warn("[Hook] Reminder: review changes before push (git diff / git status).")
        }
      }

      // Block creation of random documentation files (new .md/.txt)
      if (blockRandomDocs && (tool === "write" || tool === "edit")) {
        const p = getArg(args, ["filePath", "file_path", "path", "filename"])
        if (!p) return
        const norm = normalizeSlash(p)
        if (!/\.(md|txt)$/i.test(norm)) return
        if (isAllowedDocPath(norm)) return
        if (!isNewFile(p)) return // allow edits to existing docs

        die(
          "[Hook] BLOCKED: creating ad-hoc documentation files is disabled for repo hygiene.\n" +
            `[Hook] File: ${norm}\n` +
            "[Hook] Use an existing doc entry point (README/AGENTS) or an approved docs directory.\n" +
            "[Hook] Disable with OPENCODE_BLOCK_RANDOM_DOCS=0"
        )
      }
    },

  }
}
