// Safety plugin: approximate Codex execution policy (.codex/rules/*.rules)
// by denying obviously destructive shell commands before they run.

const BLOCK_LIST = [
  // disk/format/wipe
  /\bdd\b/i,
  /\bmkfs(\.|\b)/i,
  /\bdiskpart\b/i,
  /\bformat\b\s+[a-z]:/i,
  /\bshutdown\b/i,
  /\breboot\b/i,
  /\bpoweroff\b/i,

  // rm -rf / or ~
  /\brm\b\s+-rf\b\s+\//i,
  /\brm\b\s+-rf\b\s+~\b/i,
]

export const CodexSafety = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (!input || input.tool !== "bash") return
      const args = output && output.args ? output.args : {}
      const text = JSON.stringify(args)

      for (const re of BLOCK_LIST) {
        if (re.test(text)) {
          throw new Error(
            "Blocked potentially destructive command (CodexSafety). " +
              "If you really intend this, run it manually outside the agent."
          )
        }
      }
    },
  }
}
