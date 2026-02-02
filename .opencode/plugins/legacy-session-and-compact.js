import fs from "fs"
import path from "path"

function ensureDir(p) {
  if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true })
}

function dateString(d) {
  const y = String(d.getFullYear())
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

function timeString(d) {
  const hh = String(d.getHours()).padStart(2, "0")
  const mm = String(d.getMinutes()).padStart(2, "0")
  const ss = String(d.getSeconds()).padStart(2, "0")
  return `${hh}:${mm}:${ss}`
}

function readText(p) {
  try {
    return fs.readFileSync(p, "utf8")
  } catch {
    return ""
  }
}

function writeText(p, t) {
  fs.writeFileSync(p, t, "utf8")
}

function appendText(p, t) {
  fs.appendFileSync(p, t, "utf8")
}

function replaceLine(text, re, replacement) {
  const lines = text.split(/\r?\n/)
  let changed = false
  const out = lines.map((l) => {
    if (re.test(l)) {
      changed = true
      return replacement
    }
    return l
  })
  return { text: out.join("\n"), changed }
}

export const LegacySessionAndCompact = async ({ directory }) => {
  const stateDir = path.join(directory, ".opencode", "state")
  const sessionsDir = path.join(directory, ".opencode", "sessions")
  const compactionLog = path.join(sessionsDir, "compaction-log.txt")
  ensureDir(stateDir)
  ensureDir(sessionsDir)

  const today = dateString(new Date())
  const sessionFile = path.join(sessionsDir, `${today}-session.md`)
  const counterFile = path.join(stateDir, `tool-count-${today}.txt`)

  const threshold = Number.parseInt(process.env.COMPACT_THRESHOLD || "50", 10)

  function touchSessionFile() {
    const now = new Date()
    const ts = timeString(now)
    if (!fs.existsSync(sessionFile)) {
      const tpl =
        `# Session: ${today}\n` +
        `**Date:** ${today}\n` +
        `**Started:** ${ts}\n` +
        `**Last Updated:** ${ts}\n\n` +
        `---\n\n` +
        `## Current State\n\n` +
        `[Session context goes here]\n\n` +
        `### Completed\n- [ ]\n\n` +
        `### In Progress\n- [ ]\n\n` +
        `### Notes for Next Session\n-\n`
      writeText(sessionFile, tpl)
      return
    }
    const cur = readText(sessionFile)
    const r = replaceLine(cur, /^\*\*Last Updated:\*\*.*$/, `**Last Updated:** ${ts}`)
    if (r.changed) writeText(sessionFile, r.text)
  }

  function bumpToolCount() {
    let count = 0
    const cur = readText(counterFile).trim()
    if (cur) {
      const n = Number.parseInt(cur, 10)
      if (!Number.isNaN(n)) count = n
    }
    count += 1
    writeText(counterFile, String(count))

    if (count === threshold) {
      // eslint-disable-next-line no-console
      console.log(`[StrategicCompact] ${threshold} tool calls reached - consider compaction if transitioning phases`)
    }
    if (count > threshold && count % 25 === 0) {
      // eslint-disable-next-line no-console
      console.log(`[StrategicCompact] ${count} tool calls - good checkpoint for compaction if context is stale`)
    }
  }

  // Initialize a session file eagerly.
  touchSessionFile()

  return {
    // General event stream (see docs/plugins#events).
    event: async ({ event }) => {
      if (!event || !event.type) return

      if (event.type === "session.created") {
        touchSessionFile()
      }
      if (event.type === "session.idle" || event.type === "session.updated") {
        touchSessionFile()
      }
    },

    // Count tool invocations to suggest strategic compaction.
    "tool.execute.after": async () => {
      bumpToolCount()
    },

    // Preserve continuity through compaction by injecting the current session notes.
    // This is the OpenCode equivalent of Claude Code's PreCompact hook.
    "experimental.session.compacting": async ({ output }) => {
      try {
        touchSessionFile()
        const now = new Date()
        const ts = `${dateString(now)} ${timeString(now)}`
        appendText(compactionLog, `[${ts}] Context compaction triggered\n`)

        const snapshot = readText(sessionFile)
        if (output && Array.isArray(output.context) && snapshot) {
          // Keep it bounded to avoid ballooning the compacted context.
          const bounded = snapshot.length > 15000 ? snapshot.slice(-15000) : snapshot
          output.context.push({
            type: "text",
            text:
              "Session continuity notes (auto-injected before compaction):\n\n" +
              bounded,
          })
        }
      } catch {
        // Best-effort; never block compaction.
      }
    },
  }
}
