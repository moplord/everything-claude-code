# REQ-XXX - <短标题>

Status: DRAFT | APPROVED | IMPLEMENTING | DONE | DEPRECATED
Version: v0.1.0
Owner: <name/team>
Last Updated: YYYY-MM-DD

# Metadata (Required)
Type: <system|cross-cutting|domain-model|consumer-feature|cross-service-contract|module>
Level: <L0|L1|L2|L3|...>
Parent: <REQ-XXX-...|>
Scopes: <comma-separated; required for consumer-feature>
References: <REQ IDs + versions; required for consumer-feature>
Service: <monolith|service-name|cross-service|>

## 0. 快速阅读指南

- 只想了解“要做什么”：阅读 1-5 + 9（验收标准）
- 需要推导模型/测试/质量门禁：阅读对应的 `-appendix.md`（仍是需求文档，不是实现稿）

## 1. 摘要

- 本需求要实现什么能力（1-3 句）。
- 为谁解决什么问题，带来什么价值。

## 2. 背景 / 现状

- 当前行为与痛点
- 相关约束（系统、流程、合规、性能）

## 3. 目标（必须实现）

- G1：
- G2：

## 4. 非目标（明确不做）

- NG1：
- NG2：

## 5. 相关角色

- 用户/角色：
- 产品：
- 研发：
- 安全：
- 运维：

## 6. 用户流程（概念层）

- 主流程：
- 异常流程：
- 明确不支持的边界情况：

## 7. 功能性需求（行为层）

使用 SHALL/SHOULD/MAY 降低歧义。

- FR1（SHALL）：
- FR2（SHOULD）：

## 8. 非功能性需求（需求级）

尽量量化；不要写 CI YAML 或具体实现命令。

- NFR1（性能）：
- NFR2（可靠性）：
- NFR3（安全）：
- NFR4（可观测性）：
- NFR5（合规）：

## 9. 验收标准（权威）

每条必须可验证，并在附录里给出“验收 -> 测试类型/证据”的映射。

- AC1：
- AC2：
- AC3：

## 10. 风险与假设

- 风险：
- 假设：

## 11. 待确认问题（APPROVED 前必须清零）

- Q1：
- Q2：

## 12. 版本历史

- v0.1.0（YYYY-MM-DD）：初稿

