---
name: pr-review-frontend
description: 针对指定 GitHub PR 的一次性前端代码审查技能。使用时先获取 PR 元数据和 diff，再加载 front_end_review 规则做中文评审；不负责监控、批量扫描、iTerm 通知或默认提交评论。
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
- 不默认向 PR 提交评论

## 工作流

1. 获取 PR 标识
   - 优先使用完整 PR URL
   - 如果只有编号，先在当前仓库中解析成对应 PR

2. 拉取上下文
   - `gh pr view <pr_url> --json number,headRefOid,repository,baseRefName,headRefName,title,body,author,url`
   - `gh pr diff <pr_url>`
   - 必要时再查看 PR files、reviews、comments

3. 加载前端审查规则
   - 读取 `$WORK_HOME/auto_coding/prompt/front_end_review/` 下的角色文件
   - 至少覆盖以下视角：
     - `general-coding-standards-checker`
     - `code-reviewer`
     - `project-structure-check`
     - `javascript-reviewer`
     - `frontend-spec-check`
     - `silent-failure-hunter`
     - `pr-test-analyzer`
     - `comment-analyzer`

4. 形成审查结论
   - 先列高置信度问题，再列次要问题
   - 每条问题写明文件、行号或片段、影响、建议
   - 只保留有实际影响的问题，不写表扬性内容
   - 如果没有明显问题，明确写“未发现阻塞性问题”并给出轻量建议

## 审查输出

输出应包含：

- 结论摘要
- 问题清单，按严重程度排序
- 对每个问题的简短解释和修改建议
- 测试或风险提示

## 提交策略

默认只生成审查结果，不自动提交 PR 评论。
如果用户明确要求提交，再使用 GitHub CLI 或现有提交流程。

