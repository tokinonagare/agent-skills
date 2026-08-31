---
name: herdr-orchestration
description: 用于要关掉一个 herdr agent、判断某个 agent 是不是真的做完了、怀疑派出去的 prompt 没被收到、或者收工要清理 agent 与它的 worktree 和分支时
---

# 用 herdr 派活给并行 agent

## 核心

**herdr 的 CLI 形状与直觉不符，而 `agent_status` 不是进度。**
判据一律落到 git 状态与 context 增长上，别信状态字段，也别信「命令返回了就是做成了」。

> 该不该派活（而不是自己改）是另一件事，见 `dispatching-code-changes` skill。
> 仓库特有的事实（基点分支、端口分段、验证口径）见该仓的并行开发文档。

## 一、CLI 的实际形状

### `herdr agent` 没有 `kill`

子命令只有：`list get read send-keys prompt rename focus wait attach start explain`。

`herdr agent kill` **不是「会失败的命令」，而是不存在的子命令**——参数解析失败本会打印出来。
**让它变静默的是你自己**：实测把 stdout/stderr 一起丢进 `/dev/null`，于是 7 个 agent 一个没关，
worktree 却删了，而我已经报了「已清理」。

```bash
herdr agent list          # 取 tab_id
herdr tab close <tab_id>  # 关闭 agent 的唯一手段
```

**教训不是「herdr 有会静默失败的命令」，而是丢弃输出会把正常报错变成静默。**
凡 herdr 命令：别丢输出，或事后用 `herdr agent list` 复核目标真的没了。

### `worktree create` 与 `tab create` 会各建一个 pane

`herdr worktree create` 自己就开一个 pane；随后再 `herdr tab create` 指到同一目录就有两个。
每次都发生。用 `herdr pane list` 按 cwd 分组，关掉多余那个。

### `agent read` 的限制

`--lines` **超过一屏**且 agent 在 `working` 时报 `agent_not_idle`；一屏内的 `--lines` 或
`--source visible` **恒可读**。盯正在跑的用 `--source visible`，看完整报告等 idle。

`read` 返回**渲染滞后的快照**——发完 `prompt`/`send-keys` 后第一次读常看不到变化，**要再读一次**。

## 二、`agent_status` 不能当真

| 值 | 实际可能是 |
|---|---|
| `idle` | 停下来等你拍板；或**零产出**就结束（任务本来就不用做） |
| `working` | 卡在 `vi` 等交互；或空转 |
| `done` | 这一轮回合结束，不代表推了分支或建了 MR |

真正的判据：

```bash
git -C <worktree> log --oneline origin/dev..HEAD      # 有没有提交
git -C <worktree> status --porcelain | wc -l          # 有没有未提交改动
git -C <worktree> ls-remote --heads origin <branch>   # 推了没有（传分支名，不是目录名）
```

外加 `herdr agent read <n> --source visible` 底部的 **context 百分比**——它是「吃进了多少」的唯一可靠信号。

## 三、启动期的已知失效

**pi 的第一条 prompt 会被吞**：`agent start --kind pi` 后立刻 `prompt`，context 停在 `0.0%`。
每次都这样。固定做法是**发两轮，用 context 百分比验收**，仍是 `0.0%` 就补发。

起 pi 时加 `--tools read,bash,edit,write,agent_browser`，绕开 MCP 适配器暴露非法工具名
（违反 `^[a-zA-Z0-9_-]+$`）导致的 deepseek API 400。claude 不需要双发，但同样用 context 验收。

**输入行里的中文可能是建议灰字**：`read` 看 idle 的 agent 时，`❯` 行常有一句你没输过的贴切中文。
那是缓冲区为空时渲染的建议，**不是待提交内容**，`prompt` 不会与它拼接。

## 四、边界会被重新解释

派活 prompt 写的边界（不要 push / 不要合并 / 不要关 issue / 不要改标签），agent 会重新解释后越过去。

真实案例：某 agent 在 issue 留言里**原文写下**「我不自行改 `P2` 标签，请定夺」，10 小时后自己改成了 P1。

**收工逐条实查，不看自述**：

```bash
git ls-remote --heads origin dev main                     # dev/main 有没有被动
glab api projects/:id/issues/<n>/resource_label_events     # 标签有没有被改
```

在 prompt 里正面写「收工后我会逐条核验，不看你的自述」——实测越界明显减少。

**`AskUserQuestion` 在 herdr 派活链路里是死路**：问题到不了派活者，bypass 模式会自动选「推荐」项，
agent 当成你批准了。prompt 里明确禁止，改为「写进报告等我答复」。

## 五、清理

```bash
herdr tab close <tab_id>                    # 先关 agent，否则 worktree 被占
git worktree remove <path>                  # 有未提交残留才加 --force
git worktree prune
git branch -d <branch>                      # 用 -d 不用 -D：未合入会拒绝，天然是闸门
```

`-d` 判定的是「合入当前分支」，所以先 `git checkout dev && git pull`，否则在别的分支上会误报未合入。
**曾经凭手感 `-D` 删掉过一条未合入的分支，靠 reflog 才捞回来。**

零提交零改动的 agent（任务本来就不用做）不需要过闸，但要先确认**确实**是零。

## 危险信号

- 把 herdr 命令的输出丢进 `/dev/null` 后宣布「已清理」
- 用 `agent_status` 判断「做完了」，没查 git
- 说某个 agent「还在跑」，但没看 context 有没有涨
- 转述 agent 的「边界已遵守」，没自己查 dev / issue / 标签
- 用 `-D` 删分支
