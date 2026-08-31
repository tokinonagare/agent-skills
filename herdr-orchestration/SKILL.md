---
name: herdr-orchestration
description: 用于要关掉一个 herdr agent、判断某个 agent 是不是真的做完了、怀疑派出去的 prompt 没被收到、或者收工要清理 agent 与它的 worktree 和分支时；也用于给 herdr agent 写派活 prompt、或核验它有没有越过你划的边界
---

# 用 herdr 派活给并行 agent

## 核心

herdr 的坑集中在**两类**：

1. **CLI 的实际形状与直觉不符** —— 你以为存在的命令不存在，而失败是**静默**的；
2. **`agent_status` 不是「干得怎么样」** —— 它只说终端在不在动，不说有没有产出、有没有卡住、有没有停下来等你。

**核心原则：状态字段不是进度，命令返回 0 不代表做成了。判据一律落到 git 与 context 增长上。**

## 何时使用

- 用 `herdr agent start` / `herdr agent prompt` 向一个或多个 agent 派活
- 需要判断某个 agent 是「做完了」「卡住了」还是「停下来等你拍板」
- 收工要清理 agent / tab / worktree

## 一、CLI 的实际形状

### `herdr agent` **没有 `kill`**

子命令只有：`list get read send-keys prompt rename focus wait attach start explain`。

`herdr agent kill <name>` **不是「会失败的命令」，而是根本不存在的子命令**——它走的是参数
解析失败，本来会打印出来。

**让它变成静默的是你自己**：2026-08-31 实测，连着对 7 个 agent 调用它、并把 stdout/stderr
一起丢进 `/dev/null`，于是什么都没看见，worktree 删了、会话全在，而我已经报了「已清理」。

> 教训不是「herdr 有个会静默失败的命令」，而是**丢弃输出会把一个正常的报错变成静默**。
> 防错方向要对：别去猜哪些命令会静默失败，而是**不要丢弃输出**。

**关闭 agent = 关它所在的 tab**：

```bash
herdr agent list          # 取 tab_id
herdr tab close <tab_id>  # 这才是唯一的关闭手段
```

> **凡是 herdr 命令，都不要把 stderr/stdout 丢弃后直接宣布成功**——要么检查返回内容，
> 要么之后用 `herdr agent list` 复核那个名字确实没了。

### `worktree create` 与 `tab create` **会各建一个 workspace**

`herdr worktree create` 自己会开一个 workspace/pane；如果你随后又 `herdr tab create`
指到同一个目录，就有**两个** pane 指向同一个 worktree。实测每次都发生。

处理：`herdr pane list` 按 cwd 分组，保留你要用的那个（启动 agent 的那个），
`herdr tab close` 掉另一个。孤儿 pane 留着不致命，但会让 `pane list` 越来越难读。

### `agent read` 的两个限制

| 情况 | 行为 |
|---|---|
| `--lines` **超过一屏**且 agent 正在 `working` | 报 `agent_not_idle`（alternate-screen 历史只能在 idle 时滚动捕获） |
| `--lines` 在一屏内，或 `--source visible` | **恒可读**，working 时也能读 |

所以盯一个正在跑的 agent，用 `--source visible`；要看完整报告，等它 idle 再用 `--lines N`。

`read` 还会返回**渲染滞后的陈旧快照**——发完 `send-keys` / `prompt` 后第一次读常常看不到变化，
**要再读一次才作数**。

## 二、`agent_status` 为什么不能当真

| 值 | 你以为 | 实际可能是 |
|---|---|---|
| `idle` | 做完了 | 停下来等你拍板；或**零产出**就结束了（任务本来就不用做） |
| `working` | 在推进 | 卡在 `vi` 等交互；或在空转 |
| `done` | 交付了 | 只说明这一轮回合结束，不代表推了分支或建了 MR |

**真正的判据**（每次都查，不看状态字段）：

```bash
git -C <worktree> log --oneline origin/dev..HEAD      # 有没有提交
git -C <worktree> status --porcelain | wc -l          # 有没有未提交改动
git -C <worktree> ls-remote --heads origin <branch>   # 推了没有
```
外加 `herdr agent read <n> --source visible` 底部的 **context 百分比**——
它是「这个 agent 到底吃进了多少东西」的唯一可靠信号。

> ⚠️ `ls-remote` 要传**分支名**，不是 worktree 目录名。传错会恒返回空，
> 让你误判成「没推」。

## 三、启动期的已知失效

### pi：**第一条 prompt 会被吞**

`herdr agent start --kind pi` 之后立刻 `agent prompt`，context 会停在 `0.0%`
——prompt 进了还没准备好的缓冲区。实测每一次都这样。

**固定做法：发两轮，并用 context 百分比验收**

```bash
herdr agent start "$n" --kind pi --pane "$P" -- --tools read,bash,edit,write,agent_browser
sleep 10
herdr agent prompt "$n" "$(cat prompt.txt)"
sleep 30
# 若 context 仍是 0.0%，补发一次
```

`--tools read,bash,edit,write,agent_browser` 是绕开 MCP 适配器暴露非法工具名
（违反 `^[a-zA-Z0-9_-]+$`）导致 deepseek API 400 的既有解法。

### claude：不需要双发，但同样要用 context 验收

### 输入行里的中文可能是**建议灰字**

`agent read` 看 idle/done 的 agent 时，输入行 `❯ ...` 里常有一句你没输过的贴切中文。
那是 Claude Code 在缓冲区为空时渲染的建议，**不是待提交内容**，`agent prompt` 不会与它拼接。
判据：`ctrl+u` 清不掉、敲字会盖住、清掉那个字它又回来。

## 四、边界会被重新解释——收工必须自己核验

派活 prompt 里写的边界（不要 push / 不要合并 / 不要关 issue / 不要改标签），
**agent 会把它重新解释成意图后越过去**。

真实案例：某 agent 在 issue 留言里**原文写下**「我不自行改 `P2` 标签，请定夺」，
10 小时后自己把标签改成了 P1。查 `resource_label_events` 才发现。

**收工核验清单**（逐条实查，不看 agent 自述）：

```bash
git ls-remote --heads origin dev main        # dev/main 有没有被动
glab issue view <n> | grep '^state:'         # issue 有没有被关
glab api projects/:id/issues/<n>/resource_label_events   # 标签有没有被改
glab mr view <n> | grep -i merge             # MR 有没有被自己合掉
```

**在 prompt 里正面写出「收工后我会逐条核验，不看你的自述」**，并把上面那个真实案例贴进去
——实测这么写之后越界明显减少。

另：**`AskUserQuestion` 在 herdr 派活链路里是死路**——问题到不了派活者，
bypass 模式会自动选中「推荐」项，agent 会当成你批准了。prompt 里要明确禁止，
改为「写进报告等我答复」。

## 五、一轮派活的闭环

```
调研 → 写进 issue → 派活 → 独立验收 → 反馈返工 → 合并 → 过硬闸清理
```

### 1. 调研写进 issue，不写进 prompt

先自己把根因、影响面、行号、为什么某条路走不通查清楚，**写进 issue**，
prompt 里只说「issue 里已经查全，不要重新调研这些」。

好处：agent 不会浪费上下文重查；结论留在 issue 上给后人；
**你自己也被迫先想清楚**——很多次「疑似缺陷」在这一步就发现根本不成立
（例如某单派下去才发现功能三天前已经合了，agent 零产出返回是正确行为）。

### 2. prompt 的固定骨架

| 段 | 内容 |
|---|---|
| 环境 | worktree 路径、分支、基点已核验、端口段、**「不需要重装依赖」** |
| 先读 | 仓内的并行开发文档 + 项目规范（引路径，**不要复制事实**） |
| 任务 | 一句话根因 + 「issue 里已查全，别重查」 |
| 已知的坑 | 这一单最容易翻车的地方，**具体到行号和失效形态** |
| 验证 | 变异可证 + 贴红绿两次输出 + **变异前先确认变异生效** |
| 落地 | rebase → 重跑 → push → MR → `Closes`/`Part of` 口径 → **停下来别自己合** |
| 边界 | 上一节那套 + 「收工我会逐条核验」 |

### 3. 验收另起一套

见 `verifying-delegated-work` skill：数字自己跑、守卫用变异证明。

### 4. 清理必须过「已合入」硬闸

```bash
merged=$(git branch --contains "$(git rev-parse "$br")" -r | grep -c 'origin/dev')
[ "$merged" -ge 1 ] || { echo "闸门未过，保留"; continue; }
herdr tab close "$tab"; git worktree remove --force "$wt"; git branch -D "$br"
```

**删分支前一定要过这一闸**——曾经凭手感删掉过一条未合入的分支，靠 reflog 才捞回来。
零提交零改动的 agent（任务本来就不用做）不需要过闸，但要先确认**确实**是零。

## 危险信号

- 你把 herdr 命令的输出丢进 `/dev/null` 后宣布「已清理」
- 你用 `agent_status` 判断「做完了」，没查 git
- 你说某个 agent「还在跑」，但没看 context 有没有涨
- 你转述了 agent 的「边界已遵守」，没自己查 dev/issue/标签
- 你删了分支，但没跑过「已合入 dev」的判断

**以上任一条成立：先查，再下结论。**
