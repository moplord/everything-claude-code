// Root transcript logger.
//
// Goal: persist a "complete" machine-readable activity log for the session into
// the repository root, without depending on OpenCode internals.
//
// What it logs:
// - Every event OpenCode emits via the generic `event` stream (best-effort).
// - tool.execute.before/after snapshots (best-effort).
//
// Output:
// - <repo>/CHATLOG.ndjson (newline-delimited JSON).
//
// Notes:
// - If OpenCode emits chat/message events in the event stream, they will be logged too.
// - This does not retroactively reconstruct past conversations; it logs from now on.

import fs from "fs"
import path from "path"

function nowIso() {
  return new Date().toISOString()
}

function safeJson(obj) {
  try {
    return JSON.stringify(obj)
  } catch {
    // Avoid crashing the session on circular structures.
    return JSON.stringify({ ts: nowIso(), type: "logger.error", error: "json.stringify.failed" })
  }
}

function appendLine(filePath, obj) {
  try {
    fs.appendFileSync(filePath, safeJson(obj) + "\n", "utf8")
  } catch {
    // Best-effort; never block.
  }
}

export const RootTranscript = async ({ directory }) => {
  const logFile = path.join(directory, "CHATLOG.ndjson")

  // Touch the file so users can find it immediately.
  appendLine(logFile, { ts: nowIso(), type: "logger.started" })

  return {
    event: async ({ event }) => {
      if (!event || !event.type) return
      appendLine(logFile, { ts: nowIso(), type: event.type, data: event.data ?? null })
    },

    "tool.execute.before": async (input, output) => {
      try {
        appendLine(logFile, {
          ts: nowIso(),
          type: "tool.execute.before",
          tool: input?.tool ?? null,
          args: (output && output.args) || null,
        })
      } catch {
        // ignore
      }
    },

    "tool.execute.after": async (input, _output, result) => {
      try {
        appendLine(logFile, {
          ts: nowIso(),
          type: "tool.execute.after",
          tool: input?.tool ?? null,
          // Keep output bounded to avoid huge logs; still "complete enough" for tooling.
          result:
            typeof result === "string"
              ? result.slice(0, 20000)
              : result && typeof result === "object"
                ? result
                : null,
        })
      } catch {
        // ignore
      }
    },
  }
}

