# AI + 需求 -> JDL -> 代码 -> CI 全闭环蓝图（权威需求驱动）

本文档描述的不是 OpenCode/Codex 的安装细节，而是你前面定义的那套“端到端研发与 CI 闭环体系”——从 AI 讨论、生成权威需求文档、派生 JDL、生成代码、拆解任务、实现、测试、质量扫描、制品归档、镜像发布、运行监控、再反哺需求与任务的完整流程。

本文档强调：

- **需求文档是权威**（单一真相源 / Source of Truth）
- JDL、CI YAML、代码都是**下游可再生成工件**（Derived Artifacts），可以重建、校验、对齐
- 全流程必须**可审计、可追溯、可自动验证**（否则“权威”无法成立）

---

## 1. 总览：你要的闭环是什么

你描述的闭环（概念版）：

1) 与 AI 讨论业务 -> 2) 输出“结构化权威需求文档（REQ）” -> 3) 从 REQ 派生 JDL -> 4) JHipster 生成工程骨架与实体 CRUD -> 5) AI 补齐业务逻辑与测试与 CI -> 6) Push 触发 GitLab Runner -> 7) 拉依赖（Nexus）-> 8) SonarQube 扫描 -> 9) Maven Deploy 归档 JAR 到 Nexus -> 10) Docker build/push 到 Harbor -> 11) 运行暴露 Metrics -> 12) Prometheus/Grafana 监控与告警 -> 13) 任何失败自动拆解成 Issue，再进入第 4/5 步修复并再跑

核心要求：

- **需求文档“必须足够完整”**：后续生成 JDL/代码/测试/CI 时不允许靠“猜”
- **任何失败必须可定位到需求/验收/任务**：否则无法闭环
- **越大项目越必须分片**：避免 AI 上下文吃不下（用索引、分域、分服务、分 REQ 的可组合结构解决）

---

## 2. 定义：权威需求（REQ）到底包含什么、不包含什么

### 2.1 需求（REQ）必须包含

为了确保后续派生 JDL/代码/测试/CI 时“不猜”，每个 REQ 至少包含：

1) 元信息（Metadata）
   - REQ ID、标题、版本、Owner、Last Updated、状态（Draft/Accepted/Deprecated）
   - 适用范围（Scope）：服务/模块/端（Web/H5/小程序/管理端/开放 API）

2) 业务目标（Why）
   - 业务背景、要解决的问题、成功指标（KPI/验收指标）

3) 范围与非目标（Scope / Non-Goals）
   - 这一版明确不做什么（防止需求蔓延）

4) 用户与权限（Who / Access）
   - 角色（Role）、组织结构（部门/岗位可选）、权限边界（RBAC/ABAC/RLS）

5) 功能规格（What）
   - 以“用户故事 + 业务规则 + 状态机 + 错误处理”形式描述
   - UI 交互（按钮/状态/禁用条件/展示字段/隐藏字段/编辑权限）
   - 导入导出、上传下载、批量操作、审批流（如有）

6) 数据/领域模型（Domain Model）——这是“派生 JDL 必需”的部分
   - 实体、字段、类型、长度、必填、默认值、枚举、约束（唯一/组合唯一/范围）
   - 关系：一对多/多对多/一对一、聚合边界、外键是否强制
   - 列表查询维度：过滤/排序/分页、索引需求、热路径（访问模式）

7) 验收标准（Acceptance Criteria）
   - 可验证（Given/When/Then 或表格）
   - 直接对应测试用例（单测/集成/端到端/冒烟）

8) 风险、待确认问题（Risks / Open Questions）
   - 所有不确定项必须列出并阻断“派生”

### 2.2 需求（REQ）不应该包含

为了保持“需求文档仍然像需求文档（人能读懂）”，以下内容不应放进正文：

- 具体 CI YAML 的每一行写法（属于派生工件）
- 具体 Maven/Gradle 依赖版本选型细节（属于架构决策/实现细节）
- 具体 JDL 语法本身（属于派生工件）

但允许在“附录/派生约束区”放“机器可读块”（见下一节），以便派生不猜。

---

## 3. “人可读 + 机器可派生”的写法（解决你说的：既要完整又不要像数据库设计文档）

你的痛点：

- 只写中文叙述 => JDL/代码需要猜字段类型/长度/关系
- 只写 table_name/column_name => 人读起来很痛苦，不像需求文档

解决方案：**REQ 双层结构：正文 + 附录**

### 3.1 正文（Human-first）

保持“产品/业务/交互”的表达方式：

- 页面/菜单层级
- 列表展示字段 vs 隐藏字段（如 ID）
- 按钮点击后状态变化（1->2）、可用条件、错误提示
- 上传主图、删除主图、替换主图的交互规则
- 业务规则（例如价格允许 0.5、库存不能为负、上架后可否修改）

### 3.2 附录（Machine-derivable）

在 REQ 末尾放“Domain Model Appendix”：

- 用表格明确字段类型、长度、必填、默认、校验、枚举
- 用显式关系表描述 1:N / N:M / 1:1
- 用访问模式表描述索引/查询路径（供 db-plan 派生）

重要：附录仍然是需求的一部分（权威），但不污染正文阅读体验。

---

## 4. 文件/目录的组织：如何支持超大项目（多端、多模块、可选微服务、共享数据库）

这里给出一套“可规模化”的组织方式（核心是索引与分片）：

### 4.1 推荐目录（概念）

（你可以按自己 repo 习惯落地；关键是结构与索引）

- `requirements/`
  - `INDEX.md`（总索引：按域/服务/端/状态）
  - `CHANGELOG.md`（需求层变更日志）
  - `REQ-000-全局约定.md`（命名、版本、术语、权限基线、测试基线）
  - `domains/`
    - `catalog/`（商品域）
      - `REQ-101-商品管理.md`
      - `REQ-102-商品图片与媒体.md`
    - `order/`（订单域）
  - `ACCEPTANCE/`
    - `REQ-101-acceptance.md`
  - `ARCHIVE/`（删除/废弃的 REQ，永不丢失）

### 4.2 多端怎么放（同库、多端、共享数据库）

一个 REQ 可以声明适用端：

- `Applies To: [admin-web, consumer-miniapp, open-api]`

共享数据库不会冲突，因为：

- **数据库/实体定义在“域附录”里是同一份权威**（同域同实体同字段约束）
- 不同端只是对同一实体的不同视图/权限/流程（体现在 REQ 正文与验收）

### 4.3 微服务怎么放（可选）

如果未来走微服务：

- REQ 附录中增加 `Service Boundary`（实体归属哪个服务）
- JDL 派生阶段按服务切分为多份 entity JDL（避免单文件巨大）

---

## 5. 从需求到 JDL：派生规则（必须“零猜测”）

### 5.1 JDL 的角色定位

- JDL 是下游工件：用于生成实体、关系、枚举、CRUD、DTO、分页、过滤等
- JDL 不应成为“产品需求的表达载体”，但应做到可从需求附录稳定派生

### 5.2 JDL 必须从哪些信息派生

来自 REQ 附录（Domain Model Appendix）：

- 实体名（英文标识）
- 字段名（英文标识）+ 类型 + 约束（length、required、min/max、pattern）
- 枚举定义
- 关系定义（required/optional、owner side）
- 需要生成的 UI（管理端/用户端）、DTO/Service 层策略（可在附录中声明）

**禁止派生器自行猜**：如果缺字段类型/长度/关系，必须把缺口作为 Open Questions 阻断派生。

---

## 6. JDL -> 工程骨架：JHipster 的“一次性生成”与“增量演进”

### 6.1 为什么要区分“骨架生成”和“业务实现”

你担心“每次生成代码都要重写模块”。

原则：

- **JHipster 用来生成可再生部分**（实体、CRUD、基础安全、基础前端路由等）
- 业务代码与模块化扩展用“可叠加的模块包（module-pack）”插入，做到可重复应用且幂等

### 6.2 一次性生成工程骨架（应用级配置）

应用级选择（你已给定一个初始目标）：

- monolith
- Vue3
- OAuth2/OIDC
- Maven
- PostgreSQL
- i18n/多租户暂不考虑

这类选择应该沉淀成一份“scaffold plan”（可审计、可重复），并生成 `.yo-rc.json` 或相应配置。

### 6.3 增量叠加模块（你说的 MQ、MinIO/S3、Scheduler 等）

推荐把“跨项目复用的基础能力”做成 module-pack：

- `module-pack/storage-s3-oss/`：统一 S3 兼容层（可对接 MinIO/OSS/S3）
- `module-pack/jobs-quartz/` 或 `module-pack/jobs-spring-scheduler/`：统一作业框架
- `module-pack/quality-sonarqube/`：质量扫描与门禁（如果 JHipster 不完全覆盖）
- `module-pack/mq-rocketmq/`：消息队列接入（不把 RocketMQ 本体放进去，只放集成代码与配置模板）

模块包原则：

- 幂等（重复应用不产生重复代码/重复配置）
- 版本化（能升级）
- 与 CI 集成（模块自带验证脚本/测试/检查项）

---

## 7. CI（GitLab）闭环：流水线必须做什么（以及为什么必须从需求反推）

### 7.1 你定义的流水线阶段（建议标准化成 stages）

建议 stages（示例）：

1) `req-validate`：需求文档审计（格式、版本、缺失字段、Open Questions 阻断）
2) `jdl-derive`：从需求附录派生 JDL（确定性输出）
3) `codegen`：JHipster 生成（固定版本、固定参数、可复现）
4) `module-pack`：应用模块包（storage/mq/jobs/quality…）
5) `build`：后端编译（mvn test/package）、前端构建
6) `test`：单元/集成/冒烟（可分层）
7) `scan`：SonarQube、依赖漏洞扫描、镜像漏洞扫描（Harbor/Trivy）
8) `publish`：Maven Deploy（Nexus）、Docker push（Harbor）
9) `deploy`：部署到测试环境或临时环境（可选）
10) `observe`：探针校验（health/metrics），Prometheus/Grafana 接入验证

### 7.2 失败如何自动拆解成 Issue（闭环关键）

你的目标是：

- CI 失败 -> AI 读取日志 -> 拆成 GitLab Issues -> 修复 -> 提交 -> 重新跑

要实现这一点，需要额外组件（后续落地）：

- GitLab API 接入（glab CLI 或 GitLab MCP）
- 日志采集与结构化（把关键错误片段提取成“可复现描述”）
- Issue 模板规范（确保每个 issue 可独立交付）

> 注意：这部分是“体系设计”，不应该写进每个 REQ。它属于平台/流程级文档或 module-pack/ci 模块。

---

## 8. 鉴权与权限：RBAC / Row-level / OIDC（需求阶段要不要设计）

你的问题：

- 权限分部门、行级权限等要不要在需求阶段设计？

答案（体系层面）：

1) **OIDC（认证）**：通常作为平台基线（全局能力），可以先选 Keycloak 或“JHipster 自带轻量方案”
2) **授权（权限）**：必须在需求阶段表达“谁能做什么”，否则验收不可定义
3) **行级权限（RLS/数据隔离）**：只有当业务明确需要“同角色不同数据可见”时才上；否则会复杂化

你提到的痛点：

- 代码里写死 `@PreAuthorize("hasRole('ADMIN')")` 将来角色名变化要改一堆

解决思路：

- 权限点（permission key）在代码里是稳定标识（如 `catalog.product.edit`）
- 角色/部门/组织结构在 OIDC/权限管理系统里配置，映射到 permission key
- 这样改角色名不改代码，只改配置映射

落地要点（后续模块化）：

- Spring Security 的授权可做成“权限表达式 + 动态映射”
- 前端按钮级权限也用同一 permission key 控制展示/禁用

---

## 9. 小程序/H5/多端 UI 的现实问题（生成器不足时怎么办）

你指出的现实：

- 小程序端没有像 JHipster 那样成熟的一键生成器
- AI 直接生成 UI 容易“难看/不一致/不可维护”

体系层面的解决方案（不依赖“神奇生成器”）：

1) 建立“UI 设计系统（Design System）”的最小可复用资产
   - 组件库选型 + 主题 token + 页面骨架模板
2) 需求文档里把“交互规格”写到可验证
   - 列表列定义、按钮状态、空态/错误态、上传控件交互
3) 用 module-pack 或模板库提供“好看的默认 UI 框架”
   - 小程序端可选 uniapp + 统一主题/组件封装
   - 后续可引入社区模板/商业模板（属于资产管理，不属于 REQ）

---

## 10. 体系落地所需“组件清单”（你要的：到底需要哪些组件）

下面是闭环落地时需要的组件（按层分组）：

### 10.1 文档与派生层（权威）

- REQ 规范（模板 + 索引 + 变更日志 + 审计）
- 需求审计器（requirements-audit）：确保中文/英文标题都能识别，阻断不完整需求
- JDL 派生器（jdl-derivation）：从附录产出确定性 JDL（多文件拆分）
- DB 计划派生（db-plan）：从访问模式派生索引/缓存建议（不绑定具体数据库产品）

### 10.2 生成层（工程骨架）

- JHipster scaffold（jhipster-scaffold）：可复现的应用级选择（monolith/vue3/oidc/maven/postgres）
- JHipster codegen（jhipster-codegen）：固定版本生成（避免“今天能生成、明天不能”）

### 10.3 扩展层（模块包）

- module-pack（幂等补丁/模板/验证器）
  - storage-s3-oss
  - jobs-quartz 或 jobs-scheduler
  - mq-rocketmq（或 kafka/rabbit）
  - quality-sonarqube
  - observability（metrics/logging/tracing）

### 10.4 交付层（CI/CD）

- GitLab CI 模板库（stage 标准化）
- Runner 环境基线（JDK/Node/Docker/Build cache）
- Nexus/Harbor/SonarQube/Prometheus/Grafana 集成
- 失败日志解析 -> Issue 自动创建（GitLab API）

### 10.5 AI 协作层（执行与守则）

- 讨论 -> 需求固化 -> 审计通过 -> 才允许派生
- 任务拆解规则（Issue 粒度/验收/风险）
- 自动化验证清单（build/types/lint/tests/security）

---

## 11. “当前仓库现状”与“闭环目标”的差距（非常重要）

你要的是“整套体系”，而不是某个工具的配置。

目前仓库里已经具备/已实现的部分（偏“流程与资产”）：

- OpenCode/Codex 侧：rules/skills/commands/agents 的仓库资产化与迁移（用于 AI 运行时规范）
- 历史对话：已从本机 Codex 会话导出为单文件 `CHATLOG_FULL.md`

目前仍属于“体系蓝图但未落地”的部分（需要你后续明确落地范围）：

- GitLab 项目/Runner/CI YAML 的实际模板与可运行流水线
- GitLab Issue 自动创建与闭环修复（需要 GitLab API/CLI/MCP）
- JHipster 生成与 module-pack 的真正可运行脚手架（目前是设计与技能方向，未在此文档里写死具体仓库代码实现）

> 如果你要求“从现在开始就要把 CI YAML、module-pack、JHipster 脚手架全部落地到代码里”，那会是下一轮“实现工程”，不是本说明文档一轮能解决的事情。

---

## 12. 你下一步怎么推进（最短闭环路径）

如果你要按“从 0 到 1”落地闭环，建议优先顺序：

1) 固化 REQ 模板 + audit 通过（否则下游都不可靠）
2) 固化 JDL 派生（确保“零猜测”）
3) 固化 JHipster 生成版本与参数（可复现）
4) 先跑通本地 build/test/scan（不进 CI）
5) 再把这些搬进 GitLab CI（Runner + Nexus + Sonar）
6) 最后做“失败 -> Issue -> 修复 -> 再跑”的自动闭环

---

## 附：术语表（建议在 REQ-000 维护）

- REQ：权威需求文档
- AC：验收标准/验收清单
- JDL：JHipster Domain Language（派生工件）
- module-pack：可复用、幂等的项目扩展包
- RBAC：基于角色授权
- RLS：行级安全/数据隔离
- OIDC：OpenID Connect（认证协议）

