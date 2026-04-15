---
name: woodpecker-ci-triage
description: 在提交后检查最新的 GitHub/Woodpecker CI 结果，失败时抓取 Woodpecker step 日志并据此定位或修复问题。
---

# Woodpecker CI Triage

## Overview

在提交或推送后，用这个 skill 来确认 CI 是否通过。先等一小会儿让流水线稳定下来，如果结果是红的，就去看 Woodpecker 日志。适合 PR check 还在等待、刚 push 完、或者你需要先确认具体失败点再改代码的场景。

## Workflow

1. 在 commit 或 push 之后先等 60 到 120 秒再检查状态。
1. 如果 GitHub PR / check 状态可见，先看 GitHub。
1. 如果结果仍然是 pending，或者不够明确，就直接查 Woodpecker。
1. 以 Woodpecker 的失败 step 和日志作为最终依据。
1. 如果流水线失败，只拉失败 step 的日志，并提取第一个可执行的错误点。
1. 修代码或 CI 配置，然后只再查一次。

## What To Inspect

- 优先看当前分支和 commit 对应的最新 pipeline。
- 如果有多条 pipeline，选 commit 和你刚推送的一致的那条。
- 如果 pipeline 还在跑，先再等一次再读日志。
- 如果 pipeline 已经成功，一般不要再拉日志，除非你要确认 warning。

## Woodpecker API Pattern

需要可重复执行时，优先使用 `code/woodpecker_triage.py`。
脚本会：

- 通过完整仓库名查询 `repo_id`
- 按 branch 和 event 列出 pipelines
- 选出和目标 commit 匹配的 pipeline
- 读取 pipeline 状态
- 只拉失败 step 的日志
- 把返回的日志块解码成可读文本

## Failure Triage Rules

- 优先处理真正的构建/测试失败，不要被 cache 或安装噪音带偏。
- 如果日志最后停在依赖或鉴权错误，先修这个，再看断言。
- 如果是 CI 配置问题，先改 Woodpecker 文件，再重新跑。
- 如果是测试失败，优先修最小、最直接解释日志的代码路径。
- 如果 Woodpecker 和 GitHub 的状态不一致，以 Woodpecker 的 pipeline 状态和日志为准。

## References

- [woodpecker-api.md](references/woodpecker-api.md) 里有 API endpoint 和返回结构说明。
- [woodpecker_triage.py](code/woodpecker_triage.py) 是可执行辅助脚本。
