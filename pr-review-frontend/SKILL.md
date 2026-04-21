---
name: pr-review-frontend
description: 针对指定 GitHub PR 的一次性前端代码审查技能。使用时先获取 PR 元数据和 diff，再加载 front_end_review 规则做中文评审；不负责监控、批量扫描、iTerm 通知。
---

# PR Frontend Review

## 用途

当用户要你“review 某个 PR”或“审查这个 PR”时使用本技能。它只处理一个明确指定的 PR（URL 或编号），面向前端代码审查场景。

## 核心范围

- 只审查单个 PR
- 只做一次性分析
- 默认输出中文审查结论
- 不做 watch/轮询
- 不做作者批量扫描
- 不做 iTerm 通知
- 默认通过 GitHub CLI (`gh`) 向 PR 提交审查评论

## 工作流

1. 获取 PR 标识
   - 优先使用完整 PR URL
   - 如果只有编号，先在当前仓库中解析成对应 PR

2. 获取上下文
   - `gh pr view <pr_url> --json number,headRefOid,repository,baseRefName,headRefName,title,body,author,url`
   - `gh pr diff <pr_url>`
   - 必要时再查看 PR files、reviews、comments

3. 加载审查规则
   - 读取技能目录下的 `rules/` 文件夹中的角色文件
   - 至少覆盖以下视角：
     - `general-coding-standards-checker`
     - `code-reviewer`
     - `project-structure-check`
     - `javascript-reviewer`
     - `frontend-spec-check`
     - `silent-failure-hunter`
     - `pr-test-analyzer`
     - `comment-analyzer`

4. 形成结论
   - 先列高置信度问题，再列次要问题
   - 每条问题写明文件、行号或片段、影响、建议
   - 只保留有实际影响的问题，不写表扬性内容
   - 如果没有明显问题，明确写“未发现阻塞性问题”并给出轻量建议

5. 提交结果
   - 将形成的审查结论通过 `gh pr review <pr_url> --comment -b "<结论内容>"` 或根据严重程度使用 `--request-changes` 提交。
   - 为了避免 Shell 转义问题，建议先将结论写入临时文件，再使用 `gh pr review -F <file>` 提交。
   - 如果本次工作对应某个 PR，最终结论要回发到对应 PR。

## 结果

输出应包含：

- 结论摘要
- 问题清单，按严重程度排序
- 对每个问题的简短解释和修改建议
- 测试或风险提示

## 提交策略

默认在完成分析后自动提交 PR 评论。
- 如果发现“关键 (Critical)”或“重要 (High)”级别的严重问题，应使用 `gh pr review --request-changes`。
- 如果仅有建议或轻微问题，使用 `gh pr review --comment`。
- 提交前无需再次询问用户，除非用户明确要求“仅分析不提交”。
