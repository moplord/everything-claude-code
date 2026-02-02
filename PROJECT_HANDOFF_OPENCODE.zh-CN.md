<!--
本文件是“单一交接文档”，面向 OpenCode / Agent / 人类读者。
要求：自包含；不依赖其它文档；尽可能零猜测；尽可能可复现；不包含任何密钥。
-->

# 项目交接总文档（单文件 / 让 OpenCode 直接接手整个体系）

你要的不是“配好 OpenCode”，而是一整套**AI 驱动的工程闭环体系**：

AI 讨论 -> 权威需求（REQ）-> JDL -> JHipster 生成代码骨架 -> AI 填充业务/测试 -> GitLab CI -> Sonar/Nexus/Harbor -> 监控 -> 失败自动拆 Issue -> 自愈提交 -> 再跑 CI。

本文件把这件事**从头到尾**（目标、原则、产物、目录、已完成、缺口、下一步落地方法、操作命令、边界约束）写清楚，任何一个新的 OpenCode Agent 只读本文件即可接手推进。

---

## 0. 读者与使用方式（先看这个，避免误解）

你现在维护的是一个“**平台级工作流仓库**”，而不是某个业务系统本身：

- 业务系统的代码将来由 JHipster + JDL + module-pack + AI 补全生成；
- 这个仓库的职责是：沉淀 rules/skills/plugins/templates/scripts，让“从需求到交付”可复用、可审计、可闭环。

本文中的“权威”定义：

- **权威需求（REQ）**是业务系统的 Source of Truth；
- **本仓库**是“把 REQ 转成 JDL/代码/CI/测试/质量门”的工具与规范的 Source of Truth；
- 两者相互约束：REQ 驱动派生；派生失败必须回到 REQ 补齐信息（零猜测）。

---

## 1. 一句话定义本仓库（最精确）

把原本面向 Claude Code / Codex 的“规则、技能、命令、插件、会话资产”迁移为 **OpenCode 可用的项目级资产 + 全局级资产**，并用这些资产落地你定义的“AI+CI 端到端闭环体系”，使其满足：

- 确定性（可复现、可审计）
- 可分片（大项目上下文吃得下）
- 零猜测（缺信息必须阻断并提出问题）
- 可自愈（失败能拆 Issue，Issue 能推动修复再触发 CI）

---

## 2. 北极星：你定义的闭环体系（A->K 原始蓝图 + 约束）

### 2.1 闭环链路（A->K）

你给出的闭环（保持原意）：

A. GitLab Issues：任务下达（由 AI 自动拆解/由人创建都可以）  
B. AI：基于权威 REQ 输出结构化工件（JDL/CI/代码补丁）  
C. JHipster：一键生成全栈源码骨架  
D. AI：填充业务逻辑 + 编写/修复 GitLab CI 脚本  
E. Git Push：触发独立 Runner  
F. GitLab Runner：拉取依赖（Nexus）  
G. SonarQube：自动化审计报告  
H. Maven Deploy：JAR 包归档至 Nexus  
I. Docker Build：镜像推至 Harbor（含漏洞扫描）  
J. 应用运行：暴露 Metrics 端点  
K. Prometheus/Grafana：实时监控与预警  
闭环：任一步骤失败 -> AI 自动读日志 -> 拆 Issue -> 修复提交 -> 重新触发 CI

### 2.2 体系必须满足的原则（不可妥协）

1) **REQ 权威**：下游（JDL/代码/CI/测试/质量规则）必须能从 REQ 推导并对齐。  
2) **零猜测**：派生器/生成器不得靠“像是对的”做决定；缺信息必须形成 Open Questions 并 fail。  
3) **可审计**：任何生成必须记录“输入版本/工具版本/输出版本”。  
4) **可分片**：按域/服务/端/REQ 拆分，永远不要让“单一巨文档”成为唯一输入。  
5) **安全合规**：密钥不入库；破坏性命令默认 ask/deny；CI 执行最小权限。  

---

## 3. “从需求到代码”的产物分层（权威、可读、可派生）

### 3.1 业务系统侧产物（每个项目都会有）

1) REQ（权威需求，中文、人可读）  
2) REQ 附录（Machine-derivable：实体/字段/关系/约束/权限点位/访问模式）  
3) DB-Plan（可选：DB 无关的访问模式/索引/缓存契约；用于范式与性能约束）  
4) Application JDL（应用级配置，尽量最小）  
5) Entity JDLs（实体/字段/关系，多文件拆分）  
6) 生成后的代码（JHipster 产物 + module-pack 补丁 + AI 业务补丁）  
7) 测试（单元/集成/冒烟/端到端）  
8) CI（GitLab CI YAML + 质量门 + 发布）  

### 3.2 平台仓库侧产物（本仓库要沉淀的）

1) OpenCode 全局/项目配置（权限、工具、MCP）  
2) Rules（工作纪律、安全策略、输出格式）  
3) Skills（流程：需求澄清/需求审计/JDL 派生/JHipster 生成/module-pack/CI）  
4) Plugins（等价过去 hooks：阻断危险操作、生成 transcript、注入会话上下文）  
5) Commands/Agents（OpenCode 的命令与角色化执行）  
6) 模板与脚本（REQ 模板、audit、jdl 派生、codegen、module-pack、CI 模板）  

---

## 4. 本仓库现在的“事实状态”：完成了什么 / 还缺什么

### 4.1 已完成（可验证事实）

已推送到 GitHub `main`（remote 见 4.3）：

1) OpenCode 项目级配置与资产
   - `opencode.json`（严格 JSON）
   - `opencode.jsonc`（JSONC 可读版）
   - `.opencode/`（rules/skills/agents/commands/plugins）
2) 安全策略迁移（等价 Codex “allow/ask/deny”）
   - `opencode.json` 的 `permission.bash`
   - `.opencode/plugins/codex-safety.js` 作为额外兜底
3) Claude Code hooks 行为等价迁移（OpenCode 插件）
   - `.opencode/plugins/claude-hooks-parity.js`
4) 会话连续性与压缩注入
   - `.opencode/plugins/legacy-session-and-compact.js`
5) 对话记录落盘（你要求“之前所有记录”）
   - `CHATLOG_FULL.md`（Codex 历史合并导出，UTF-8 BOM）
   - `CHATLOG.ndjson`（OpenCode 运行期事件流；`.opencode/plugins/root-transcript.js` 写入）

### 4.2 还缺什么（必须继续做，才能真的“跑起来”）

闭环是工程系统，不是文档系统；缺口必须明确：

1) Requirements 体系“可执行化”
   - 目录约定（REQ/Index/Changelog）
   - requirements-audit 脚本 + CI gate
   - 中文标题识别的稳定规则（避免中文误报）
2) REQ -> JDL 的确定性派生器
   - 严格禁止猜字段类型/长度/关系
   - 缺信息生成 Open Questions 并 fail
   - 输出多文件 JDL（按域/服务/REQ 分片）
3) JHipster scaffold/codegen 的可复现工具链
   - 固定 generator-jhipster 版本（npx 版本钉死）
   - `.yo-rc.json` 参数化生成（避免交互式漂移）
4) module-pack（模块包）机制与模块库
   - storage（S3/OSS/MinIO）
   - mq（RocketMQ/Kafka/RabbitMQ）
   - jobs（Quartz 或 Spring Scheduler）
   - quality（Sonar、依赖/镜像漏洞扫描）
   - observability（metrics、日志、trace）
5) GitLab CI 最小可跑流水线
   - build/test/scan/publish 可跑
   - Nexus/Sonar/Harbor 集成参数标准化（env 命名、证书、网络）
6) 失败 -> Issue 自动拆解与自愈回路（平台能力）
   - 结构化日志归一
   - GitLab API：创建/更新 issue、关联 commit、自动关闭
   - 安全边界（哪些自动修，哪些必须人工确认）

### 4.3 远端仓库（当前 remote）

- `origin = git@github.com:moplord/everything-claude-code.git`
- 分支：`main`

---

## 5. 仓库目录与文件全解（OpenCode 接手不需要翻目录）

### 5.1 根目录关键文件

- `AGENTS.md`：工作规范（对 Agent 生效）
- `opencode.json`：项目级 OpenCode 配置（严格 JSON）
- `opencode.jsonc`：项目级 OpenCode 配置（JSONC）
- `PROJECT_HANDOFF_OPENCODE.zh-CN.md`：本文件（唯一交接入口）
- `CHATLOG_FULL.md`：历史对话合并导出（你要求的“之前所有记录”）
- `CHATLOG.ndjson`：OpenCode 运行期事件日志（持续增长）

### 5.2 `.opencode/`（OpenCode 项目资产）

把 `.opencode/` 当作“项目内 OpenCode 工作台”：

- `.opencode/rules/`：项目规则（Markdown）
- `.opencode/skills/`：项目技能（流程沉淀）
- `.opencode/agents/`：角色化 agents（如有）
- `.opencode/commands/`：可调用 commands（如有）
- `.opencode/plugins/`：插件（等价过去 hooks）
- `.opencode/sessions/`：会话 note（插件生成；通常应 gitignore）

### 5.3 `.codex/` 与 `legacy/claude-code/`（迁移对照资产）

- `.codex/`：Codex 时代的 rules/skills（迁移对照）
- `legacy/claude-code/`：Claude Code 原始材料归档（用于追溯）

---

## 6. OpenCode 配置（全局级 + 项目级）怎么生效（你强调“全局级”）

### 6.1 全局配置（Global）

Windows 上，OpenCode 全局配置通常位于：

- `C:\\Users\\admin\\.config\\opencode\\opencode.json`
- 以及同目录下的 `rules/ skills/ agents/ commands/ plugins/`

说明：

- 全局配置不入库（不能 push 到 GitHub），避免泄漏密钥、避免污染不同项目。
- 本仓库提供可复制到全局的资产：把 `.opencode/*` 拷贝到全局目录即可全局生效。

### 6.2 项目配置（Project）

项目级配置来自仓库根目录：

- `opencode.json` / `opencode.jsonc`
- `.opencode/*`

说明：

- 项目级通常覆盖全局级（同名项按 OpenCode 合并规则）。

### 6.3 环境变量（所有密钥都必须走 env）

必须：

- `OPENAI_API_KEY`
- `OPENCODE_MODEL`（可选；建议固定，保证可复现）

可选（启用 MCP 时）：

- `CONTEXT7_API_KEY`
- `GITHUB_PERSONAL_ACCESS_TOKEN`
- `FIRECRAWL_API_KEY`
- `PPT_MCP_PYTHON`
- `PPT_MCP_SERVER`

规则：

- 不要把 token 写进仓库；不要把 token 写进 JSONC 注释里。

---

## 7. 需求体系怎么“通用化到任何规模”（多端、共享 DB、可选微服务、版本迭代、删除/重构）

你最核心的诉求：需求文档必须“人能读懂”，同时又必须“机器可推导”，并支撑：

- 多端（小程序/H5/Web 管理端/更多端）
- 共享数据库（多个端共用同一模型）
- 可选微服务（不一定采用，但能扩展）
- 超大项目（上下文吃不下，需要分片）
- 多次重构与删除（可追溯）

### 7.1 REQ 的组织方式（偏好“打开一个文件就读完”）

约定：每个 REQ 是一个 `.md` 文件，包含两层：

1) 正文（Human-first，中文需求）  
2) 附录A（Machine-derivable，表格/结构块，供派生器读取）  

派生器只扫描“附录A”区块，正文仍然保持纯需求表达。

### 7.2 REQ 的分片单位是什么

一个 REQ = 一个可验收的业务能力（常常对应菜单项/页面/流程/领域子域中的一块），必须包含：

- Scope（范围）
- Non-Goals（非目标）
- Acceptance Criteria（验收标准）
- Open Questions（待确认问题）
- Domain Model Appendix（派生附录）

### 7.3 多端怎么放、如何避免冲突

REQ metadata 必须声明适用范围（示例字段）：

- `Scope-Ends:` 例如 `AdminWeb, CustomerMiniApp`
- `Scope-Services:` 例如 `monolith`（或未来的 `order-service`）
- `Shared-Model:` `true/false`

端差异写在正文（按钮/字段显示/交互）；模型共享写在附录（实体/字段/关系）。

### 7.4 共享 DB 与可选微服务怎么兼容

兼容策略：

- REQ 附录只定义“业务实体与关系、字段约束、访问模式”
- 不在 REQ 附录绑定具体数据库厂商、具体 schema、具体分片
- 若未来拆微服务：通过 `Service-Owner:` 标注实体归属，派生时按服务输出不同 JDL 文件

### 7.5 版本迭代、重构、删除怎么记录

每个 REQ 必须包含：

- `Version:`
- `Last Updated:`
- `Status: Draft | Active | Deprecated | Deleted`
- `Changelog:`（记录每次变更）

删除需求：标记 `Status: Deleted`，保留文件；派生器必须跳过生成，并在 Index 标注删除原因与替代 REQ。

---

## 8. 从 REQ 派生 JDL（确定性，不猜；英文标识只出现在附录）

### 8.1 附录里怎么写英文标识（示例）

```md
## 附录A：领域模型（Machine-derivable）

### 实体：商品（Product）

| 中文名 | 英文标识 | 类型 | 长度/精度 | 必填 | 默认值 | 约束/校验 | 展示 | 备注 |
|---|---|---|---|---|---|---|---|---|
| ID | id | UUID | - | 是 | 自动生成 | 只读 | 隐藏 | 主键 |
| 商品名称 | name | String | 120 | 是 | - | 去首尾空格；不可重复（同店铺范围） | 显示/可编辑 | |
| 主图 | mainImage | Blob | - | 否 | - | 仅图片；大小<=2MB | 显示/可编辑 | 上传后返回 URL/Key |
| 状态 | status | Enum(ProductStatus) | - | 是 | DRAFT | 状态机见正文 | 显示/可编辑 | |

### 枚举：ProductStatus
- DRAFT
- ONLINE
- OFFLINE

### 关系
- Shop(1) -> Product(N)  (Product.shop 必填)
```

约束：

- 英文标识只出现在附录；
- 正文仍然是中文需求；
- 派生器不得猜字段类型/长度/关系；缺项必须 Open Questions 并 fail。

### 8.2 多文件 JDL 必须执行（避免超大单一 JDL）

强制拆分：

- `jdl/application.jdl`：应用级配置
- `jdl/entities/REQ-xxx-*.jdl`：每个 REQ 一份实体 JDL
- 可选：按服务拆分 `jdl/entities/<service>/*.jdl`

---

## 9. JHipster 代码生成：从“交互式”到“可复现”

你当前固定的 scaffold 目标：

- monolith
- Vue3
- oauth2-oidc
- Maven
- PostgreSQL
- i18n：不考虑
- multi-tenant：不考虑

漂移来源：

- generator 版本变化
- 交互式问答默认值变化
- 人工回答不一致

平台化做法（必须实现，当前为缺口）：

1) 固化 scaffold plan（记录选项与版本）
2) 固定 generator-jhipster 版本（npx 钉死版本）
3) 用脚本生成 `.yo-rc.json`（不要手答）
4) 运行生成器 + 记录输出版本（可审计）

---

## 10. 鉴权与权限（OIDC 可选 Keycloak；RBAC + Row-level 都要做）

### 10.1 认证（AuthN）：两条可选路径

- 路径 A：Keycloak（推荐正式环境；开源免费；功能全）
- 路径 B：轻量 IdP/开发环境方案（用于轻量项目或开发；后续可迁移）

平台要求：不管选哪个，应用代码的授权点位必须稳定（见 10.3）。

### 10.2 授权（AuthZ）：RBAC vs Row-level

- RBAC：决定“能不能做某个动作”
- Row-level：决定“能不能访问某一条数据”

两者都要做，才能避免“有权限但越权访问数据”的漏洞。

### 10.3 避免写死角色名（解决 hasRole('ADMIN') 的痛点）

统一改为“Permission Key”：

- 代码只检查权限点：`can:product.update`、`can:product.image.upload`
- 角色名/权限组合由 Keycloak（或其它权限中心）配置映射
- 角色名变化无需改代码，只改映射

### 10.4 平台化落地（做成 module-pack）

目标：把“权限点位落到前后端 + Row-level 数据过滤框架”做成 module-pack，避免每个项目重复造轮子。

---

## 11. module-pack：模块“写一次、项目复用、可升级”怎么实现

模块包不是把 MQ/MinIO 代码拷贝进仓库，而是：

- patch（对生成代码做改动）
- templates（配置、docker-compose、CI 片段）
- verifiers（验证脚本：编译、测试、质量门）

运行时依赖由 Maven/NPM 拉取；模块包只负责“引入依赖 + 接口约束 + 默认实现 + 测试”。

升级机制：

- module-pack version
- changelog
- 升级脚本（v1->v2）

---

## 12. GitLab CI：最小闭环怎么定义（先跑起来，再扩展到全闭环）

### 12.1 stages（与你 A->K 对齐）

最小可跑：

1) req-validate（requirements-audit gate）
2) jdl-derive（生成 JDL）
3) codegen（JHipster 生成骨架）
4) module-pack（套用模块包）
5) build（mvn + 前端 build）
6) test（unit + integration + smoke）
7) scan（Sonar + 依赖漏洞 + 镜像漏洞）
8) publish（Nexus + Harbor）

扩展：

- deploy（测试环境）
- observe（探针/metrics 校验）
- self-heal（失败 -> Issue -> 修复 -> 再跑）

### 12.2 为什么 CI 不写进每个 REQ

REQ 是业务意图与验收标准；CI 是平台能力，应作为 module-pack/模板维护。  
REQ 只声明“必须通过哪些质量门”（例如覆盖率阈值、漏洞等级阈值）。

---

## 13. 对话记录与可追溯性（根目录已有：全量历史 + 实时事件流）

现状：

- `CHATLOG_FULL.md`：历史对话合并导出（Codex 历史）
- `CHATLOG.ndjson`：OpenCode 运行期事件日志（持续增长）

建议：

- 默认 gitignore（避免推巨大日志）
- 若需审计：可作为 CI artifact 或归档到对象存储

---

## 14. 上游更新与迁移策略（claude/codex/opencode 三者不会自动“互相变身”）

重要事实：

- 上游如果继续更新“Claude Code 版本”，不会自动变成“OpenCode 版本”。
- 你要的是“等价迁移”，因此每次上游更新都需要迁移步骤：
  - 拉取上游变更
  - 对比 `legacy/claude-code/` 的变化
  - 把等价能力落到 `.opencode/`（rules/skills/plugins）
  - 更新本文件的“已完成/缺口”

---

## 15. 新的 OpenCode Agent 接手的第一小时（按清单做，不会迷路）

1) `git status -sb`：确认工作区干净  
2) `git log -n 20 --oneline --decorate`：确认自己在最新 main  
3) 读 `PROJECT_HANDOFF_OPENCODE.zh-CN.md`（本文件）  
4) 读 `AGENTS.md`（工作纪律）  
5) 选择一个“下一步落地子目标”（必须是一个子闭环）：
   - requirements-audit gate
   - REQ -> JDL 派生器
   - JHipster scaffold/codegen 脚本
   - module-pack 机制 + 一个模块（storage/quality）
   - GitLab CI 最小可跑流水线
6) 任何实现都必须同步更新本文件的“已完成/缺口/操作步骤”

---

## 16. 下一步建议：从哪里开始实现（按最短闭环）

建议顺序（不要跳）：

1) requirements-audit（先让“权威”可执行）
2) jdl-derivation（把“可派生”做成确定性工具）
3) jhipster-scaffold + jhipster-codegen（把“生成骨架”变成可复现脚本）
4) module-pack（先做一个最小模块：quality 或 storage）
5) gitlab-ci（先跑 build/test/scan/publish）
6) self-heal（最后做：失败 -> Issue -> 自动修复）

---

## 17. 本文件维护规则（防止再次失控）

本文件是唯一交接入口。任何重大变更都必须更新：

- 已完成什么（可验证的事实）
- 还缺什么（可执行的缺口）
- 下一步怎么做（操作步骤 + 文件路径）

