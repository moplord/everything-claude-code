# REQ-XXX 附录（领域模型）- <短标题>

Status: DRAFT | APPROVED | IMPLEMENTING | DONE | DEPRECATED
Version: v0.1.0
Owner: <name/team>
Last Updated: YYYY-MM-DD

# Metadata (Required)
Type: domain-model
Level: <L0|L1|L2|L3|...>
Parent: <REQ-XXX-...|>
Scopes: <optional; usually "all">
References: <other REQs if needed>
Service: <monolith|service-name|>

本附录与正文同等权威，但以表格结构化表达“可推导约束”。
目标：下游生成 JDL/代码/测试时不需要猜。不要在此粘贴 JDL 语法或 CI YAML。

## A. 实体与字段（JDL 可推导）

命名约定：
- 用 `EntityCode`（PascalCase）与 `FieldCode`（camelCase）作为稳定标识符。
- 不在需求里记录物理表/列名，除非是外部硬约束（用 ADR 记录）。

### A1. 实体清单

| 实体(中文) | EntityCode(PascalCase) | 描述 | 审计字段(创建人/创建时间等) | 软删除 | 乐观锁(version) | 备注 |
|---|---|---|---|---|---|---|

### A2. 字段字典（每个实体一张）

| EntityCode | 字段(中文) | FieldCode(camelCase) | 业务含义 | 类型候选(JDL) | 必填 | 默认值 | 长度/精度/Scale | 校验/范围 | 唯一/索引 | 系统维护 | 说明 | 示例 |
|---|---|---|---|---|---:|---|---|---|---|---:|---|---|

### A3. 枚举

| 枚举名 | 值 | 含义 | 默认值 | 备注 |
|---|---|---|---|---|

### A4. 关系（1:1 / 1:N / N:N）

| 关系名 | A 实体(EntityCode) | A 侧字段(FieldCode) | B 实体(EntityCode) | B 侧字段(FieldCode) | 基数 | 拥有方 | 必填 | 是否双向 | Join/字段(FieldCode) | 删除/级联 | 备注 |
|---|---|---|---|---|---|---|---:|---:|---|---|---|

### A5. 业务不变量（必须满足）

| 不变量 | 说明 | 违规时处理（错误码/提示） |
|---|---|---|

## B. 文件/图片（上传/下载合同）

| 场景 | 关联到(EntityCode.FieldCode/关联) | 存储策略 | 格式 | 大小上限 | 尺寸上限 | 替换规则 | 删除旧文件规则 | 权限 | 失败回滚 | 下载/预览 |
|---|---|---|---|---|---|---|---|---|---|---|

## C. 领域事件/接口契约（需求级，概念层）

| 契约 | 触发条件 | 输入字段 | 输出字段 | 幂等键/并发规则 | 错误码/文案 | 备注 |
|---|---|---|---|---|---|---|

## D. 验证与质量合同（需求级）

### D1. 访问模式（DB 无关）

| 场景 | 过滤字段(EntityCode.FieldCode) | 排序 | 分页 | 预期量级 | 延迟预算 | 备注 |
|---|---|---|---|---|---|---|

### D2. 索引计划（DB 无关）

| 索引名 | 实体(EntityCode) | 字段(FieldCode...) | 唯一 | 用途 | 备注 |
|---|---|---|---:|---|---|

### D3. 缓存计划（可选）

| Cache Key | Source | TTL | Invalidation | Consistency | Notes |
|---|---|---|---|---|---|

| 门禁 | 需求 | 阻断 | 备注 |
|---|---|---:|---|
