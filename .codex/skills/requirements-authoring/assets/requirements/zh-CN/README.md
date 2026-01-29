# 需求文档（权威来源）

本目录是“要做什么”的权威来源。

规则：
- 这里不是 JDL，必须保持生成器无关。
- 不要把实现细节写进 REQ。
- 每条需求必须有可验证的验收标准。
- 任何改变含义的编辑都必须提升版本并写入 CHANGELOG。

实践：
- 用 `req-index.ps1` 生成 `INDEX.md`（大型项目不要手改索引）。
- 用 `req-ledger.ps1` 更新 `requirements/.audit/ledger.json`，防止“静默漂移”。
