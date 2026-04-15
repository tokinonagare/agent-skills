---
name: gemini-woodpecker-ci-triage
description: 检查最新的 GitHub/Woodpecker CI 结果，失败时抓取 Woodpecker step 日志并据此定位或修复问题。适用于 PR 提交后、push 后或需要确认具体失败点的情况。
---

# Woodpecker CI 故障排查 (Triage)

请遵循以下说明来检查 CI 流水线状态，并从 Woodpecker CI 中抓取失败日志。

## 工作流程 (Workflow)

1.  **等待稳定性**：在 commit 或 push 后等待 60 到 120 秒再检查状态，以便流水线完成初始化。
2.  **检查状态**：如果 GitHub PR/check 状态可见，则查看它；如果状态为 pending 或不明确，则直接查询 Woodpecker。
3.  **识别失败**：以 Woodpecker 的失败步骤和日志作为最终事实来源。
4.  **抓取日志**：仅拉取失败步骤的日志。
5.  **提取错误**：从日志中识别第一个可执行的错误点。
6.  **修复并重新检查**：对代码或 CI 配置进行修复，然后再次验证。

## 检查指南 (Inspection Guidelines)

-   **定位最新**：始终检查与当前分支和 commit SHA 对应的最新流水线。
-   **匹配 Commit**：如果存在多个流水线，选择与您的目标 commit 匹配的那个。
-   **等待终止状态**：如果流水线仍在运行，请等待并重新检查，直到其达到终止状态（success, failure 等）。
-   **跳过成功**：如果流水线成功，除非是为了查找警告，否则不要拉取日志。

## 故障排查工具与规则 (Triage Tools & Rules)

### 执行脚本
使用 `scripts/woodpecker_triage.py` 进行自动排查。它负责仓库查找、流水线选择和日志拉取。

### 失败分析规则
-   **优先处理真实失败**：关注构建或测试失败；如果是缓存或安装噪音且不阻塞构建，请忽略。
-   **优先解决依赖问题**：在分析断言失败之前，先修复依赖或鉴权错误。
-   **CI 配置**：如果是 CI 设置本身失败，请先更新 Woodpecker 配置文件。
-   **最小化修复**：专注于能够解决错误日志的最小且最直接的代码更改。

## 相关资源 (Resources)

-   [woodpecker-api.md](references/woodpecker-api.md)：详细的 API 接口文档和数据结构说明。
-   `scripts/woodpecker_triage.py`：自动化排查辅助脚本。
