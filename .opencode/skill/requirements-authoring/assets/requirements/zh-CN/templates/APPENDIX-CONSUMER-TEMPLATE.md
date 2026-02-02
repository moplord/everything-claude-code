# REQ-XXX 附录（消费方/功能）- <短标题>

Status: DRAFT | APPROVED | IMPLEMENTING | DONE | DEPRECATED
Version: v0.1.0
Owner: <name/team>
Last Updated: YYYY-MM-DD

# Metadata (Required)
Type: consumer-feature
Level: <L0|L1|L2|L3|...>
Parent: <REQ-XXX-...|>
Scopes: <comma-separated; required>
References: <domain-model REQ + version; required>
Service: <monolith|service-name|optional>

本附录与正文同等权威，用于把“该功能如何使用共享模型”与“可验证合同”写清楚。
它不定义数据库模型（字段类型/关系等必须来自引用的 domain-model）。

## A. Model Snapshot（只摘录本需求用到的模型；只读）

来源：References 中的 domain-model（写明版本）。

### A1. 相关实体与字段（摘录）

| 实体(中文) | EntityCode | 字段(中文) | FieldCode | 用途 | 备注 |
|---|---|---|---|---|---|

### A2. 相关关系（摘录）

| 关系名 | A 实体(EntityCode) | B 实体(EntityCode) | 基数 | 用途 | 备注 |
|---|---|---|---|---|---|

## B. 字段投影（显示/隐藏/可编辑/只读）

每个 Scope 可以有不同投影；不写类型，不写长度（这些属于 domain-model）。

命名：字段引用一律使用 `EntityCode.FieldCode`（例如 `Product.mainImage`）。

| Scope | EntityCode.FieldCode | UI可见 | 可编辑 | 隐藏原因/只读原因 | 说明 |
|---|---|---:|---:|---|---|

## C. 交互与状态机（业务层）

### C1. 行为/按钮/操作合同

| Scope | 操作 | 触发条件 | 输入 | 状态变化 | 成功反馈 | 失败反馈 | 审计日志 | 备注 |
|---|---|---|---|---|---|---|---|---|

### C2. 状态机（如果涉及状态字段，必须填写）

| EntityCode.FieldCode | from | event（按钮/动作） | guard（条件） | to | 副作用 | 备注 |
|---|---|---|---|---|---|---|

## D. 文件/图片（上传/下载合同，若涉及则填写）

| Scope | 场景 | 关联到(EntityCode.FieldCode/关联) | 格式 | 大小上限 | 替换规则 | 权限 | 失败回滚 | 下载/预览 |
|---|---|---|---|---|---|---|---|---|

## E. 验收 -> 测试 -> 证据（可追溯）

| AC | Scope | 测试类型（unit/integration/smoke/e2e） | 证据要求（CI链接/日志/截图） | 备注 |
|---|---|---|---|---|

## F. 质量门禁（需求级，不写 YAML）

| 门禁 | 需求 | 阻断 | 备注 |
|---|---|---:|---|
