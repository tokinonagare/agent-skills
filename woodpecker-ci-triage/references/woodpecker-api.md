# Woodpecker API 参考

## Purpose

这个 skill 使用 Woodpecker 官方 API 来查看仓库的最新 pipeline，并在失败时抓取 step 日志。

## Authentication

- 发送 `Authorization: Bearer <personal access token>`。
- 使用目标 Woodpecker server 的个人访问 token。

## Key Endpoints

- `GET /repos/lookup/{repo_full_name}`: 把 `owner/repo` 解析成 `repo_id`。
- `GET /repos/{repo_id}/pipelines`: 列出仓库 pipelines。
- `GET /repos/{repo_id}/pipelines/{number}`: 获取单条 pipeline。
- `GET /repos/{repo_id}/logs/{number}/{step_id}`: 获取单个 step 的日志。
- `GET /stream/logs/{repo_id}/{pipeline}/{step_id}`: 流式读取 step 日志。
- `GET /stream/events`: 流式读取 pipeline 更新事件。

## Pipeline Fields To Watch

- `status`: 最终状态，比如 success 或 failure。
- `number`: pipeline 编号，日志路径会用到。
- `commit`: 用来匹配 push 的 commit SHA。
- `branch`: 用来匹配 push 的分支名。
- `workflows[].children[]`: 有需要时可当作 step 列表。
- `workflows[].children[].id`: 日志接口需要的 step id。
- `workflows[].children[].state`: 用来找失败 step。
- `workflows[].children[].exit_code`: 用来找第一个非 0 退出码。

## Triage Flow

1. 先解析 repository id。
1. 再列出目标分支和事件对应的 pipelines。
1. 选出 commit 和刚推送内容一致的 pipeline。
1. 如果 pipeline 还在运行，就再等一次后重查。
1. 如果 pipeline 失败，找出失败的 step id。
1. 拉取每个失败 step 的日志，提取第一个可执行的错误点。
