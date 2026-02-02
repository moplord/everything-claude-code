# OpenCode 从零到可用：全流程说明（全局级 + 项目级 + 历史对话导出）

本文档把“这件事从头到尾”完整说明清楚：我们做了什么、为什么这么做、文件/目录在哪、哪些是全局配置、哪些是项目配置、如何验证是否生效、如何导出历史对话到单一文件、以及常见坑位。

> 重要原则：**全局级配置用于“所有项目默认行为”**；项目级配置用于“某个项目的专用约束/技能/命令”。两者可以共存，且 OpenCode 会做合并/覆盖（项目级通常优先生效）。

---

## 0. 目标与交付物（你最终要得到什么）

你要的结果分 3 类：

1) **OpenCode 全局级配置（Global）**
   - 位置：`C:\Users\admin\.config\opencode\opencode.json`
   - 作用：在任何目录启动 OpenCode 都有统一的默认行为（模型/权限/MCP/rules/skills 等）。

2) **OpenCode 项目级配置（Project）**（在本仓库内）
   - 位置：仓库根目录的 `opencode.json`（严格 JSON，无注释）与 `opencode.jsonc`（可读性强）
   - 作用：只对本项目生效；用于把 `.opencode/` 目录下的规则/技能/命令/agent 作为“项目资产”管理与版本化。

3) **“之前所有对话记录”的单文件导出**
   - 位置：本仓库根目录 `CHATLOG_FULL.md`
   - 作用：把你本机 Codex 历史会话（`~/.codex/sessions` 和 `~/.codex/archived_sessions`）提取并合并成**一个**可读文件。
   - 编码：`UTF-8 with BOM`（Windows 记事本打开不乱码）

另外还有一个“从现在开始记录 OpenCode 会话事件”的日志文件：

- `CHATLOG.ndjson`：由 OpenCode 插件实时写入（只覆盖 OpenCode 运行期间的事件；不是历史回溯）。

---

## 1. 本机 OpenCode 的“全局路径”在哪里（先确认标准）

在 Windows 上，你可以用 OpenCode 自带命令确认路径（以当前机器为准）：

```powershell
opencode debug paths
```

在本机输出显示（已验证）：

- config: `C:\Users\admin\.config\opencode`
- data: `C:\Users\admin\.local\share\opencode`
- state: `C:\Users\admin\.local\state\opencode`
- cache: `C:\Users\admin\.cache\opencode`

**因此：全局配置文件必须放在：**

- `C:\Users\admin\.config\opencode\opencode.json`

---

## 2. 全局级配置（Global）：我们写入了什么、放在哪、怎么生效

### 2.1 全局文件/目录结构（必须是 plural 形式）

OpenCode 全局目录遵循 plural 命名（已按官方说明创建）：

- `C:\Users\admin\.config\opencode\opencode.json`
- `C:\Users\admin\.config\opencode\rules\`
- `C:\Users\admin\.config\opencode\skills\`
- `C:\Users\admin\.config\opencode\agents\`
- `C:\Users\admin\.config\opencode\commands\`
- `C:\Users\admin\.config\opencode\plugins\`
- （可选）`tools/`、`themes/`、`modes/`

> 注意：`agent/`、`command/` 这类 singular 目录虽然兼容，但这里我们按官方推荐使用 plural。

### 2.2 全局 opencode.json 的关键内容（为什么这么写）

全局 `opencode.json` 主要做这些事：

1) **不写死模型与密钥（避免泄露/便于多机复用）**
   - `model` 使用环境变量：`{env:OPENCODE_MODEL}`
   - `OPENAI_API_KEY` 使用环境变量：`{env:OPENAI_API_KEY}`

2) **全局 rules 生效**
   - `instructions`: `["~/.config/opencode/rules/*.md"]`

3) **全局 skills 生效**
   - `skills.paths`: `["~/.config/opencode/skills"]`

4) **权限策略（全局默认）**
   - 默认：`bash` 需要询问（ask）
   - 明确允许：只读安全命令（`rg*`、`git status/diff/log/show/...`）
   - 明确拒绝：高危破坏命令（`dd*`、`mkfs*`、`rm -rf /` 等）
   - 明确提示：`git reset --hard*` / `git clean -fdx*` 等“破坏性但可恢复/需要明确意图”的命令

5) **全局 MCP（默认关闭）**
   - 内置了 semgrep/context7/chrome-devtools/ppt 的“模板”，默认 `enabled:false`
   - 所有密钥/路径均为 env 占位符，避免写死

> 重要：全局 `opencode.json` 已修复为 **UTF-8 无 BOM**（OpenCode/JSON 解析更稳）。

### 2.3 全局 plugins（把“hooks”能力迁移到 OpenCode）

OpenCode 支持把插件放在：

- `~/.config/opencode/plugins/`

我们已经把以下插件复制到全局插件目录：

- `claude-hooks-parity.js`：把 Claude Code 的 hooks 行为做等价迁移（tmux 提示/阻止、阻止乱建 md、console.log 警告等）
- `legacy-session-and-compact.js`：会话笔记 + compaction 时注入上下文
- `codex-safety.js`：安全兜底（防止少数高危命令）
- `root-transcript.js`：把 OpenCode 运行过程中的事件写到项目根目录 `CHATLOG.ndjson`

这些插件默认“随 OpenCode 启动而启用”（因为它们放在全局 plugins 目录里）。

### 2.4 全局配置的验证方法（必须做）

1) 查看 OpenCode 是否识别到全局 config：

```powershell
opencode debug paths
```

2) 查看“解析后的最终配置”（注意：会受你当前目录是否有项目 opencode.json 影响）：

```powershell
opencode debug config
```

> 解释：OpenCode 会合并“全局 config + 项目 config + .opencode 目录内容”。如果你在某个项目目录里运行，它会显示项目级的影响，这是正常的。

---

## 3. 项目级配置（Project）：为什么仍然需要、现在有什么

你要全局级没错，但项目级仍然有价值：

- **把规则/skills/commands/agents 作为仓库资产版本化**（团队可同步、可审计、可回滚）
- 某些项目可以覆盖全局默认（例如更严格权限、更专用 MCP、更专用命令）

本仓库的项目级资产在这里：

### 3.1 项目级配置文件

- `opencode.json`：严格 JSON（无注释），用于兼容只认 `.json` 的读取路径
- `opencode.jsonc`：可读性强（带注释），用于人工阅读与维护

### 3.2 项目级 .opencode 目录（项目资产）

- `.opencode/rules/`：规则/规范（你让我们迁移的各类规则）
- `.opencode/skills/`：技能（仓库内版本）
- `.opencode/commands/`：命令（带 YAML frontmatter，并使用 `$ARGUMENTS`）
- `.opencode/agents/`：agents
- `.opencode/plugins/`：项目内插件（与全局插件互补）
- `.opencode/sessions/`、`.opencode/state/`：运行时生成（已被 `.gitignore` 忽略）

---

## 4. “之前所有对话记录”导出为一个文件（你要的单文件）

你要的是：“包含之前所有你和我对话的记录，合并成一份文件”。

### 4.1 历史记录真实来源（Codex 本机目录）

Codex 历史记录在本机：

- `C:\Users\admin\.codex\history.jsonl`（简化索引）
- `C:\Users\admin\.codex\sessions\**\rollout-*.jsonl`（完整会话日志）
- `C:\Users\admin\.codex\archived_sessions\rollout-*.jsonl`（归档会话）
- `C:\Users\admin\.codex\log\codex-tui.log`（日志）

我们为了“在当前项目根目录下可见”，把它们拷贝进了仓库（但不会提交）：

- `codex-history.jsonl`
- `codex-sessions/`
- `codex-archived_sessions/`
- `codex-tui.log`

### 4.2 生成的单文件（最终你要看的）

- `CHATLOG_FULL.md`
  - 合并来源：`codex-sessions/**.jsonl` + `codex-archived_sessions/**.jsonl`
  - 内容：提取 `response_item` 中 `message` 的 `role=user/assistant` 与文本，按 session 分段输出
  - 编码：`UTF-8 BOM`（Windows 记事本不乱码）

> 注意：这是“过去的 Codex 历史对话导出”，与 OpenCode 的 `CHATLOG.ndjson`（运行中事件日志）是两条线。

---

## 5. .gitignore：为什么必须加、我们加了哪些

你要求“放在项目根目录”，但这些内容通常包含路径/上下文/潜在敏感信息，不适合提交到公开仓库，所以我们做了默认保护：

- 忽略 OpenCode 运行时状态：
  - `.opencode/state/`
  - `.opencode/sessions/`
- 忽略日志导出：
  - `CHATLOG.ndjson`
  - `CHATLOG_FULL.md`
- 忽略 Codex 本机拷贝过来的历史与日志：
  - `codex-history.jsonl`
  - `codex-tui.log`
  - `codex-sessions/`
  - `codex-archived_sessions/`

如果你“就是要提交这些到 GitHub”，请你手动移除 `.gitignore` 对应行，再自行 `git add/commit/push`。

---

## 6. 你接下来要做什么（最短路径）

### 6.1 必需的环境变量（否则 model/apiKey 为空）

全局配置用 env 占位符，所以你至少要设置：

- `OPENAI_API_KEY`
- `OPENCODE_MODEL`（例如：`openai/gpt-5`，按你真实可用模型填）

（可选）你启用对应 MCP 时再补：

- `CONTEXT7_API_KEY`
- `PPT_MCP_PYTHON`、`PPT_MCP_SERVER`
- `GITHUB_PERSONAL_ACCESS_TOKEN`
- `FIRECRAWL_API_KEY`

### 6.2 验证“全局级已生效”的最可靠方式

1) 在任意一个**没有项目 opencode.json** 的目录（比如 `C:\Users\admin`）运行：

```powershell
cd C:\Users\admin
opencode debug config
```

你应当看到：

- `skills.paths` 指向 `~/.config/opencode/skills`
- `instructions` 指向 `~/.config/opencode/rules/*.md`

2) 在本仓库运行（会叠加项目级配置），也是正常的：

```powershell
cd D:\Code\everything-claude-code-1.1.0
opencode debug config
```

---

## 7. 常见问题/坑位（你之前遇到的“为什么不行”）

1) **你说“我要全局级”，但看到的是项目级效果**
   - 因为你在项目目录里启动 OpenCode，项目 `opencode.json` 会参与合并；
   - 这不是“全局没生效”，而是“项目覆盖/叠加了全局”。

2) **JSON BOM 导致解析异常**
   - 我们遇到过：写入全局 `opencode.json` 时出现 BOM，Python `json` 解析报错；
   - 已修复：全局 `opencode.json` 当前为 UTF-8 无 BOM。

3) **插件配置字段不是 `plugins` 而是 `plugin`**
   - OpenCode schema：`plugin` 是数组（用于加载 npm 插件包）
   - 本地插件文件的加载方式是放在 `~/.config/opencode/plugins/` 或 `.opencode/plugins/`

---

## 8. 这一轮我们实际做过的关键动作（可审计点）

你如果只想快速确认“东西在不在”，看这 3 个位置：

1) 全局 config：
   - `C:\Users\admin\.config\opencode\opencode.json`

2) 全局 assets（rules/skills/commands/agents/plugins）：
   - `C:\Users\admin\.config\opencode\{rules,skills,commands,agents,plugins}\`

3) 历史对话单文件导出：
   - `D:\Code\everything-claude-code-1.1.0\CHATLOG_FULL.md`

---

## 9. 你要我继续补齐什么（下一步选项）

如果你说“全局还不够”，通常还差三类：

1) **全局默认 agent**（指定默认 agent 名称/角色）
2) **全局默认 commands/agents 的命名与说明**（便于在任何项目快速调用）
3) **MCP 启用策略**（默认关闭；你希望哪些默认开启、哪些按项目开启）

你直接告诉我你希望“全局默认 agent 是哪个”、“哪些 MCP 要全局开启”，我就按你的偏好把全局 `opencode.json` 再补齐。

