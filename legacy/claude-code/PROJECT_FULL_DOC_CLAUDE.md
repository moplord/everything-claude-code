# 项目全量文档：everything-claude-code

> 目标：让读者只读此文档即可完整理解该项目的结构、原理、操作方式与文件关系（全量覆盖，逐文件说明）。

## 1. 项目定位与总体原理

这是一个 **Claude Code 插件仓库**，核心目的不是“应用代码”，而是**配置、规则与自动化工作流集合**。它通过以下机制组合工作：

- **Plugin 清单**（`.claude-plugin/*`）让 Claude Code 识别本项目为可安装插件，并声明“commands、skills 的入口目录”。
- **命令（commands）**提供可被 `/命令` 触发的工作流说明。
- **代理（agents）**定义不同职责的子代理角色（如规划、审查、安全、E2E）。
- **技能（skills）**提供可复用流程与模式库，支持自动触发或手动调用。
- **Hooks（hooks/hooks.json）**在特定事件点（PreToolUse、PostToolUse、SessionStart/End、PreCompact、Stop）触发脚本，做提醒、格式化、持久化、模式提取等。
- **脚本（scripts/）**提供跨平台（Windows/macOS/Linux）可执行逻辑，作为 hooks 的实现主体。
- **规则（rules）**是“必须遵循”的规范集合，通常被复制到用户的 `~/.claude/rules/`。
- **上下文（contexts）**作为系统提示的可插拔注入模式（dev/review/research）。
- **测试（tests）**验证脚本与 hooks 的正确性。
- **示例（examples）**提供模板与会话记录样例。
- **MCP 配置**提供多种外部工具的接入示例（需自行填密钥）。

整体“运行原理”的主线是：  
**Claude Code** 读取插件清单 → 加载 commands/skills → 执行 hooks 中定义的脚本 → 脚本读写本地 `.claude` 目录（会话、学习、包管理器偏好）→ agents/skills/rules 提供行为规范与流程模板。

---

## 2. 顶层目录结构速览

```
.
|-- .claude/                 # 项目级 Claude 配置（仅包管理器偏好）
|-- .claude-plugin/           # 插件清单与市场清单
|-- agents/                   # 子代理定义（角色、流程）
|-- commands/                 # /命令 说明与操作流程
|-- contexts/                 # 上下文模式（dev/review/research）
|-- examples/                 # 示例配置与会话样例
|-- hooks/                    # Claude Code hooks 配置
|-- mcp-configs/              # MCP 服务器示例配置
|-- plugins/                  # 插件与市场的说明文档
|-- rules/                    # 强制规则（安全/编码/测试/工作流）
|-- scripts/                  # Node 脚本（hooks 实现、工具逻辑）
|-- skills/                   # 技能库（流程/模式/学习系统）
|-- tests/                    # 脚本/钩子测试
|-- README.md / CONTRIBUTING.md / .gitignore
```

---

## 3. 文件级全量说明（逐文件）

### 3.1 根目录文件

**.gitignore**  
作用：排除环境文件、密钥、编辑器目录、node_modules、个人配置与示例会话模板等。  
操作原理：标准 Git 忽略规则；特别忽略 `examples/sessions/*.tmp`（会话模板）。  
关系：配合 hooks/skills 的“会话持久化/学习”，避免把临时会话提交进仓库。

**README.md**  
作用：项目主说明与安装方式；解释插件结构、跨平台支持、包管理器检测、目录内容、测试命令。  
操作原理：文档说明为主，无可执行逻辑。  
关系：与 `.claude-plugin` 指向同一项目定位；与 scripts/、hooks/、skills 等内容互相引用。

**CONTRIBUTING.md**  
作用：贡献指南，说明添加 agents/skills/commands/hooks/rules/MCP 的格式与流程。  
操作原理：文档说明为主。  
关系：与各目录格式约定一致（frontmatter、命令说明结构）。

---

### 3.2 `.claude/`

**.claude/package-manager.json**  
作用：记录项目级包管理器偏好。  
操作原理：由 `scripts/setup-package-manager.js` 或手动设置写入。  
关系：被 `scripts/lib/package-manager.js` 在检测逻辑中读取（优先级高于 package.json、锁文件等）。

---

### 3.3 `.claude-plugin/`

**.claude-plugin/plugin.json**  
作用：插件元信息清单。  
操作原理：Claude Code 读取此文件确定插件名称、作者、主页、license，并加载 `commands` 与 `skills` 目录。  
关系：与 `commands/` 和 `skills/` 强绑定（入口目录即这两个路径）。

**.claude-plugin/marketplace.json**  
作用：市场清单，允许将本仓库作为 marketplace 加入并安装。  
操作原理：Claude Code marketplace 读取该文件以列出插件列表（此处只有一个插件）。  
关系：与 `plugin.json` 对应，描述同一插件的市场可见信息。

---

### 3.4 `plugins/`

**plugins/README.md**  
作用：插件与市场的安装指南，给出推荐 marketplace 与插件列表。  
操作原理：文档说明。  
关系：补充 README 中的插件安装方法。

---

### 3.5 `agents/`（子代理定义）

> agents 文件均为“Claude Code 子代理指令”，通过 frontmatter 指定 name/description/tools/model。

**agents/architect.md**  
作用：架构师代理，负责系统设计、扩展性评估与架构取舍。  
实现原理：提供架构评审流程、设计原则、ADR 模板、反模式与扩展计划。  
关系：常与 `/plan`、`/orchestrate` 联动，指导大改动前的架构决策。

**agents/planner.md**  
作用：规划代理，负责拆解复杂任务为阶段性步骤与风险评估。  
实现原理：固定的计划格式（Requirements、Steps、Testing、Risks）。  
关系：`/plan` 命令直接调用；也是 `/orchestrate feature` 的第一环。

**agents/tdd-guide.md**  
作用：TDD 专家代理，强制测试先行，覆盖率 80%+。  
实现原理：明确的 RED → GREEN → REFACTOR 流程与测试样例。  
关系：`/tdd` 命令直接调用；与 `rules/testing.md`、`skills/tdd-workflow` 一致。

**agents/code-reviewer.md**  
作用：代码审查代理，必须用于变更后审查。  
实现原理：按严重级别输出问题，含安全检查清单。  
关系：`/code-review` 命令调用；与 `rules/security.md`、`rules/coding-style.md` 相互呼应。

**agents/security-reviewer.md**  
作用：安全审查代理，覆盖 OWASP、秘钥检查、注入、鉴权等。  
实现原理：工具清单 + 漏洞模式 + 输出模板。  
关系：与 `skills/security-review` 和 `rules/security.md` 同方向；`/orchestrate security` 会调用。

**agents/build-error-resolver.md**  
作用：构建错误与 TS 报错修复代理，仅做最小改动。  
实现原理：先收集报错，逐条最小修复；强调不改架构。  
关系：`/build-fix` 命令执行相同策略；与 `rules/performance.md` 中“build失败用该代理”一致。

**agents/refactor-cleaner.md**  
作用：死代码清理与重复合并代理。  
实现原理：knip/depcheck/ts-prune 检测 → 风险分级 → 分批删除 → 测试验证 → 记录 DELETION_LOG。  
关系：`/refactor-clean` 命令流程一致；与 `rules/testing.md` 强制测试联动。

**agents/doc-updater.md**  
作用：文档与 codemap 更新代理。  
实现原理：通过 ts-morph/madge/jsdoc 生成结构与文档，保持一致性。  
关系：`/update-docs`、`/update-codemaps` 命令触发；与 docs/CODEMAPS 思路一致。

**agents/e2e-runner.md**  
作用：端到端测试代理，优先使用 Vercel Agent Browser，Playwright 兜底。  
实现原理：定义测试结构、POM 模式、artifact 管理与 flaky 管控。  
关系：`/e2e` 命令触发；与 `rules/testing.md` 里的 E2E 要求配套。

**agents/database-reviewer.md**  
作用：PostgreSQL 审核与优化代理，强调索引、RLS、安全与性能。  
实现原理：给出 SQL 审查流程与模式库（基于 Supabase best practices）。  
关系：与 `skills/postgres-patterns` 互补；数据库相关任务优先调用。

---

### 3.6 `commands/`（/命令定义）

> 命令文件是“使用说明与步骤约束”，多数并不直接执行，而是指示代理/用户行动流程。

**commands/build-fix.md**  
作用：增量修复 build/TS 错误流程。  
实现原理：逐错误处理，修复后重复构建。  
关系：对应 `agents/build-error-resolver.md` 的“最小修复”原则。

**commands/checkpoint.md**  
作用：工作流 checkpoint（创建/验证/列出）。  
实现原理：调用 `/verify quick`、使用 git stash/commit、记录 `.claude/checkpoints.log`。  
关系：与 `commands/verify.md` 联动；与 hooks 的会话持久化互补。

**commands/code-review.md**  
作用：代码审查流程说明。  
实现原理：基于 git diff、按安全/质量/最佳实践分类。  
关系：与 `agents/code-reviewer.md` 细则一致。

**commands/e2e.md**  
作用：触发 E2E 测试代理并生成测试。  
实现原理：说明使用 Playwright/Agent Browser，输出 artifacts 与报告。  
关系：调用 `agents/e2e-runner.md`。

**commands/eval.md**  
作用：Eval 驱动开发（define/check/report/list）。  
实现原理：创建 `.claude/evals/*.md`，记录日志并输出报告模板。  
关系：与 `skills/eval-harness` 相同理念。

**commands/learn.md**  
作用：手动抽取可复用模式为 skills。  
实现原理：把模式写入 `~/.claude/skills/learned/`，保存前需用户确认。  
关系：与 `skills/continuous-learning` 的自动抽取互补。

**commands/orchestrate.md**  
作用：多代理串联工作流（feature/bugfix/refactor/security/custom）。  
实现原理：按顺序或并行调用 agent，并通过 HANDOFF 文档传递上下文。  
关系：强依赖 agents 的标准化输出格式。

**commands/plan.md**  
作用：创建实施计划并“等待用户确认”。  
实现原理：强调先计划后执行，禁止未确认写代码。  
关系：与 `agents/planner.md` 一致。

**commands/refactor-clean.md**  
作用：死代码清理流程说明。  
实现原理：使用 knip/depcheck/ts-prune 分级处理并强制测试。  
关系：与 `agents/refactor-cleaner.md` 一致。

**commands/setup-pm.md**  
作用：设置包管理器偏好。  
实现原理：调用 `node scripts/setup-package-manager.js`，检测与写入配置。  
关系：与 `scripts/setup-package-manager.js`、`scripts/lib/package-manager.js` 直接关联。

**commands/tdd.md**  
作用：TDD 工作流说明。  
实现原理：RED → GREEN → REFACTOR，强调覆盖率 80%+。  
关系：对应 `agents/tdd-guide.md` 与 `skills/tdd-workflow`。

**commands/test-coverage.md**  
作用：覆盖率分析与补测流程。  
实现原理：读取 coverage summary，针对低覆盖文件补测试。  
关系：与 `rules/testing.md` 一致。

**commands/update-codemaps.md**  
作用：codemap 更新流程。  
实现原理：扫描代码结构生成架构文档，变化 >30% 时要求确认。  
关系：对应 `agents/doc-updater.md` 的 codemap 生成流程。

**commands/update-docs.md**  
作用：文档同步流程。  
实现原理：以 package.json 和 .env.example 为单一真源，生成 docs。  
关系：与 `agents/doc-updater.md` 的“源码驱动文档”理念一致。

**commands/verify.md**  
作用：全面验证（build/type/lint/test/log/secret/git diff）。  
实现原理：按顺序执行并输出 PASS/FAIL 报告。  
关系：与 `skills/verification-loop` 同步；常用于 checkpoint 或 PR 前。

---

### 3.7 `contexts/`（上下文注入）

**contexts/dev.md**  
作用：开发模式提示，偏实现优先、写代码先于解释。  
关系：与 dev 工作流、tests、commit 习惯一致。

**contexts/review.md**  
作用：审查模式提示，强调安全与可维护性。  
关系：与 code-reviewer/security-reviewer 指令一致。

**contexts/research.md**  
作用：研究模式提示，先理解再执行。  
关系：与探索性任务、多代理检索一致。

---

### 3.8 `examples/`（示例）

**examples/CLAUDE.md**  
作用：项目级 CLAUDE.md 模板。  
原理：指导项目范围内的规则、结构、命令使用。  
关系：与 `rules/`、`commands/` 内容一致。

**examples/user-CLAUDE.md**  
作用：用户级 CLAUDE.md 模板（全局规则）。  
关系：和 `rules/`、`agents/`、`skills/` 的模块化配置对应。

**examples/statusline.json**  
作用：Claude Code 状态栏命令示例。  
原理：通过命令读取当前 workspace、模型、上下文剩余等，生成彩色状态行。  
关系：与 `~/.claude/settings.json` 中 statusLine 配置配合使用。

**examples/sessions/2026-01-17-debugging-memory.tmp**  
作用：会话记录样例（内存泄漏调查）。  
原理：展示 Session 文件结构与“Context to Load”字段。  
关系：与 `scripts/hooks/session-end.js` 生成的会话模板一致。

**examples/sessions/2026-01-19-refactor-api.tmp**  
作用：会话记录样例（API 重构）。  
关系：同上。

**examples/sessions/2026-01-20-feature-auth.tmp**  
作用：会话记录样例（JWT 认证开发）。  
关系：同上。

---

### 3.9 `hooks/`

**hooks/hooks.json**  
作用：Claude Code hooks 配置中心。  
实现原理：基于 matcher 触发命令，覆盖 PreToolUse/PostToolUse/PreCompact/SessionStart/Stop/SessionEnd。  
关键行为：
- 阻止非 tmux 启动 dev server
- 提醒长任务用 tmux
- git push 提醒
- 禁止随意创建 md/txt
- 自动建议 /compact
- 代码格式化与 tsc 检测
- console.log 预警与会话结束审计
- SessionStart/End 时调用脚本保存/加载状态
关系：直接调用 `scripts/hooks/*.js`；依赖 `scripts/lib/*` 的工具函数。

---

### 3.10 `mcp-configs/`

**mcp-configs/mcp-servers.json**  
作用：MCP 服务器示例配置（GitHub、Supabase、Vercel、Cloudflare、ClickHouse 等）。  
实现原理：提供 MCP server 启动命令与必要的 env placeholder。  
关系：被用户手动复制到 `~/.claude.json` 以启用；与 README 的“不要同时启用太多 MCP”一致。

---

### 3.11 `rules/`（必须遵守的规则）

**rules/agents.md**  
作用：规定何时调用哪个 agent，以及并行策略。  
关系：与 commands/orchestrate 的代理链一致。

**rules/coding-style.md**  
作用：编码风格与错误处理、输入验证要求（强调不可变）。  
关系：与 skills/coding-standards、agents/code-reviewer 一致。

**rules/git-workflow.md**  
作用：提交格式与 PR 规范；规定 planner → tdd → review 的开发流程。  
关系：与 commands/plan、commands/tdd、commands/code-review 一致。

**rules/hooks.md**  
作用：hooks 机制概览与使用原则。  
关系：解释 hooks.json 的设计动机。

**rules/patterns.md**  
作用：API response、hook 模式、repository pattern 等通用模板。  
关系：与 skills/backend-patterns/coding-standards 一致。

**rules/performance.md**  
作用：模型选择与上下文管理策略。  
关系：与 strategic-compact 及多代理使用方式一致。

**rules/security.md**  
作用：安全检查清单（提交前必须做）。  
关系：与 agents/security-reviewer、skills/security-review 同步。

**rules/testing.md**  
作用：测试要求（TDD、80% 覆盖、E2E）。  
关系：与 agents/tdd-guide、commands/tdd、skills/tdd-workflow一致。

---

### 3.12 `scripts/`（执行逻辑）

**scripts/setup-package-manager.js**  
作用：交互式包管理器设置脚本。  
原理：解析 CLI 参数，调用 `scripts/lib/package-manager.js` 写入全局或项目配置。  
关系：被 `/setup-pm` 命令指向。

**scripts/lib/utils.js**  
作用：跨平台工具函数库（路径、时间、文件、命令、git）。  
原理：封装 fs/path/os/child_process，提供通用函数，如 `getSessionsDir()`、`readStdinJson()`。  
关系：被所有 hooks 脚本与包管理器逻辑复用。

**scripts/lib/package-manager.js**  
作用：包管理器检测/选择/命令生成。  
原理：按优先级读取 env → 项目配置 → package.json → lockfile → 全局配置 → fallback。  
关系：由 `setup-package-manager.js` 与 `session-start.js` 调用。

**scripts/hooks/session-start.js**  
作用：SessionStart hook：发现最近会话、学习技能并提示包管理器。  
原理：读取 `~/.claude/sessions`、`~/.claude/skills/learned`；调用 package-manager。  
关系：由 hooks.json 的 SessionStart 事件触发。

**scripts/hooks/session-end.js**  
作用：SessionEnd hook：创建或更新 session 文件。  
原理：在 `~/.claude/sessions/` 生成 `YYYY-MM-DD-<id>-session.tmp` 模板。  
关系：与 examples/sessions 模板一致。

**scripts/hooks/pre-compact.js**  
作用：PreCompact hook：在自动 compaction 前记录状态。  
原理：在 session 文件追加“compaction发生”标记，并写日志。  
关系：与 hooks.json 的 PreCompact 配置关联。

**scripts/hooks/suggest-compact.js**  
作用：在 Edit/Write 前提示“适时手动 compact”。  
原理：用临时计数文件记录 tool call 次数，达到阈值提醒。  
关系：与 skills/strategic-compact/suggest-compact.sh 同主题（JS 版本）。

**scripts/hooks/evaluate-session.js**  
作用：Stop hook：在会话结束时判断是否需要“提取可复用模式”。  
原理：读取 `skills/continuous-learning/config.json`，统计 transcript 中 user 消息数。  
关系：与 skills/continuous-learning 完整流程对应。

---

### 3.13 `skills/`（技能库）

> skills 是“流程/模式/知识库”，可被手动触发或由系统判断激活。

**skills/backend-patterns/SKILL.md**  
作用：后端模式大全（API、Repository、Service、缓存、错误处理、鉴权）。  
原理：以模式模板与伪代码示例约束后端实现。  
关系：与 agents/architect、database-reviewer、rules/patterns 同方向。

**skills/frontend-patterns/SKILL.md**  
作用：前端模式大全（组合、hooks、状态管理、性能、可访问性）。  
关系：与 rules/coding-style 的 React 部分互补。

**skills/tdd-workflow/SKILL.md**  
作用：完整 TDD 流程技能。  
关系：与 agents/tdd-guide、commands/tdd、rules/testing 一致。

**skills/coding-standards/SKILL.md**  
作用：通用编码规范（命名、不可变、错误处理、TS 习惯）。  
关系：与 rules/coding-style 共鸣。

**skills/security-review/SKILL.md**  
作用：安全审查技能（鉴权、输入校验、CSRF/XSS、防注入等）。  
关系：与 agents/security-reviewer、rules/security 同步。

**skills/security-review/cloud-infrastructure-security.md**  
作用：云基础设施安全技能（IAM、CI/CD、日志、WAF、备份）。  
关系：扩展 security-review 为云场景。

**skills/postgres-patterns/SKILL.md**  
作用：PostgreSQL 模式速查。  
关系：与 agents/database-reviewer、skills/clickhouse-io 区分数据库类型。

**skills/project-guidelines-example/SKILL.md**  
作用：项目级指南示例模板（架构、文件结构、部署、测试）。  
关系：鼓励在真实项目里建立“专属规则”。

**skills/eval-harness/SKILL.md**  
作用：Eval 驱动开发框架（capability/regression evals，pass@k）。  
关系：与 commands/eval.md 直接配套。

**skills/strategic-compact/SKILL.md**  
作用：战略性 compaction 建议。  
关系：与 hooks 中 suggest-compact.js 同目标。

**skills/strategic-compact/suggest-compact.sh**  
作用：shell 版本 compaction 提示脚本。  
关系：可作为 hooks 中 command 使用（Unix 环境）。

**skills/iterative-retrieval/SKILL.md**  
作用：解决“子代理上下文不足”的迭代检索策略。  
关系：与 rules/agents 的并行策略互补。

**skills/continuous-learning/SKILL.md**  
作用：v1 持续学习机制说明（Stop hook → 提取技能）。  
关系：与 scripts/hooks/evaluate-session.js & evaluate-session.sh 关联。

**skills/continuous-learning/config.json**  
作用：持续学习配置（最小会话长度、输出路径、忽略模式）。  
关系：被 `scripts/hooks/evaluate-session.js` 与 `evaluate-session.sh` 读取。

**skills/continuous-learning/evaluate-session.sh**  
作用：shell 版本 Stop hook（统计消息数并提示提取技能）。  
关系：与 JS 版本功能一致。

**skills/continuous-learning-v2/SKILL.md**  
作用：v2 本能系统设计文档（instincts、confidence、观察 hook）。  
关系：与 continuous-learning-v2 子目录中的脚本/命令相互配合。

**skills/continuous-learning-v2/config.json**  
作用：v2 系统配置（观察存储、instincts、observer、evolution）。  
关系：供 v2 scripts 与 hooks 使用。

**skills/continuous-learning-v2/commands/instinct-status.md**  
作用：列出本能状态命令 `/instinct-status`。  
关系：调用 `instinct-cli.py status`。

**skills/continuous-learning-v2/commands/instinct-import.md**  
作用：导入本能命令 `/instinct-import`。  
关系：调用 `instinct-cli.py import`。

**skills/continuous-learning-v2/commands/instinct-export.md**  
作用：导出本能命令 `/instinct-export`。  
关系：调用 `instinct-cli.py export`。

**skills/continuous-learning-v2/commands/evolve.md**  
作用：聚类进化命令 `/evolve`。  
关系：调用 `instinct-cli.py evolve`。

**skills/continuous-learning-v2/agents/observer.md**  
作用：后台观察者代理定义，分析 observation 生成 instincts。  
关系：由 `start-observer.sh` 启动，读取 observations.jsonl。

**skills/continuous-learning-v2/agents/start-observer.sh**  
作用：后台 observer 的启动/停止脚本。  
关系：与 observer agent、observe.sh 的数据流互相连接。

**skills/continuous-learning-v2/hooks/observe.sh**  
作用：PreToolUse/PostToolUse hook 观察器，记录 tool 事件到 observations.jsonl。  
关系：向 observer 提供输入数据；与 v2 配置强绑定。

**skills/continuous-learning-v2/scripts/instinct-cli.py**  
作用：本能管理 CLI（status/import/export/evolve）。  
原理：读取 instincts YAML，解析 frontmatter，按 domain 聚合并输出。  
关系：被 v2 commands 调用。

**skills/clickhouse-io/SKILL.md**  
作用：ClickHouse OLAP 模式与优化策略。  
关系：与 postgres-patterns 形成数据库技能的互补体系。

**skills/verification-loop/SKILL.md**  
作用：完整验证循环（build/type/lint/test/security/diff）。  
关系：与 commands/verify.md 机制一致。

---

### 3.14 `tests/`（测试）

**tests/run-all.js**  
作用：顺序运行本仓库测试脚本并汇总结果。  
原理：node 执行测试文件，解析输出统计。  
关系：聚合 `tests/lib/*` 与 `tests/hooks/*`。

**tests/hooks/hooks.test.js**  
作用：hooks 脚本测试。  
原理：spawn node 调用脚本，断言输出/文件创建。  
关系：验证 `scripts/hooks/*` 与 `hooks/hooks.json` 的正确性。

**tests/lib/package-manager.test.js**  
作用：包管理器逻辑测试。  
关系：测试 `scripts/lib/package-manager.js` 的检测、命令生成等。

**tests/lib/utils.test.js**  
作用：工具函数测试。  
关系：测试 `scripts/lib/utils.js` 的跨平台逻辑与文件操作。

---

## 4. 关键关系图（简版）

```
plugin.json  --> commands/ + skills/
hooks.json   --> scripts/hooks/*.js --> scripts/lib/*.js
commands/*.md --> agents/*.md 或 scripts/*.js
agents/*.md  --> rules/*.md / skills/*.md 的思想体系
skills/*     --> hooks/commands/agents 的模式库
tests/*      --> scripts/hooks/lib 的验证
```

---

## 5. 使用者操作路径（从 0 到 1）

1) **安装插件**  
通过 `plugin.json` 与 `marketplace.json` 让 Claude Code 识别并安装。

2) **启用 hooks**  
将 `hooks/hooks.json` 合并进 `~/.claude/settings.json`，开启自动化提示、格式化、会话持久化。

3) **配置包管理器**  
运行 `/setup-pm` 或 `node scripts/setup-package-manager.js` 写入 `.claude/package-manager.json`。

4) **按需启用 agents/skills/rules**  
将 rules/skills/agents 拷贝到 `~/.claude/` 进行全局启用。

5) **使用 commands**  
通过 `/plan`、`/tdd`、`/verify` 等命令触发规范流程。

---

## 6. 读完你应当理解的核心原理

- **这是“Claude Code 的工作流插件”，不是业务应用。**
- **所有行为依赖 hooks → scripts → rules/skills 的链条。**
- **agents/commands/skills 三者是“流程描述的不同层级”：**
  - agents：角色化执行者
  - commands：用户触发流程说明
  - skills：可复用的模式/知识
- **tests 保证 hooks 与脚本不回归。**
- **examples 给出实际项目级/用户级配置模板。**

---

## 7. 完整文件清单索引

为便于核对，本仓库文件清单如下（与本节上文逐文件说明一一对应）：

```
.gitignore
CONTRIBUTING.md
README.md
.claude/package-manager.json
.claude-plugin/marketplace.json
.claude-plugin/plugin.json
agents/architect.md
agents/build-error-resolver.md
agents/code-reviewer.md
agents/database-reviewer.md
agents/doc-updater.md
agents/e2e-runner.md
agents/planner.md
agents/refactor-cleaner.md
agents/security-reviewer.md
agents/tdd-guide.md
commands/build-fix.md
commands/checkpoint.md
commands/code-review.md
commands/e2e.md
commands/eval.md
commands/learn.md
commands/orchestrate.md
commands/plan.md
commands/refactor-clean.md
commands/setup-pm.md
commands/tdd.md
commands/test-coverage.md
commands/update-codemaps.md
commands/update-docs.md
commands/verify.md
contexts/dev.md
contexts/research.md
contexts/review.md
examples/CLAUDE.md
examples/user-CLAUDE.md
examples/statusline.json
examples/sessions/2026-01-17-debugging-memory.tmp
examples/sessions/2026-01-19-refactor-api.tmp
examples/sessions/2026-01-20-feature-auth.tmp
hooks/hooks.json
mcp-configs/mcp-servers.json
plugins/README.md
rules/agents.md
rules/coding-style.md
rules/git-workflow.md
rules/hooks.md
rules/patterns.md
rules/performance.md
rules/security.md
rules/testing.md
scripts/setup-package-manager.js
scripts/hooks/evaluate-session.js
scripts/hooks/pre-compact.js
scripts/hooks/session-end.js
scripts/hooks/session-start.js
scripts/hooks/suggest-compact.js
scripts/lib/package-manager.js
scripts/lib/utils.js
skills/backend-patterns/SKILL.md
skills/clickhouse-io/SKILL.md
skills/coding-standards/SKILL.md
skills/continuous-learning/config.json
skills/continuous-learning/evaluate-session.sh
skills/continuous-learning/SKILL.md
skills/continuous-learning-v2/config.json
skills/continuous-learning-v2/SKILL.md
skills/continuous-learning-v2/agents/observer.md
skills/continuous-learning-v2/agents/start-observer.sh
skills/continuous-learning-v2/commands/evolve.md
skills/continuous-learning-v2/commands/instinct-export.md
skills/continuous-learning-v2/commands/instinct-import.md
skills/continuous-learning-v2/commands/instinct-status.md
skills/continuous-learning-v2/hooks/observe.sh
skills/continuous-learning-v2/scripts/instinct-cli.py
skills/eval-harness/SKILL.md
skills/frontend-patterns/SKILL.md
skills/iterative-retrieval/SKILL.md
skills/postgres-patterns/SKILL.md
skills/project-guidelines-example/SKILL.md
skills/security-review/cloud-infrastructure-security.md
skills/security-review/SKILL.md
skills/strategic-compact/SKILL.md
skills/strategic-compact/suggest-compact.sh
skills/tdd-workflow/SKILL.md
skills/verification-loop/SKILL.md
tests/run-all.js
tests/hooks/hooks.test.js
tests/lib/package-manager.test.js
tests/lib/utils.test.js
```

