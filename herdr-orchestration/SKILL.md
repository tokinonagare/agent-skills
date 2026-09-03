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

**pi 的 prompt 会被吞，但触发条件有两个**（曾误记为「第一条必被吞，每次都这样」，一批 10 个 agent 实测推翻）：

| 情形 | 结果 |
|---|---|
| prompt 是长文本（几十行任务书正文直接发） | **被吞**，渲染成 `[paste #1 +58 lines]` 挂在缓冲区 |
| 一行 prompt，`start` 与 `prompt` 之间隔了别的操作 | **7/7 一次接活**，ctx 立刻涨到 0.9%–2.7% |
| 一行 prompt，`start` 后**立刻**发 | **3/3 被吞**，ctx 停在 `0.0%` |

所以是**文本太长**或**agent 还没交互就绪**，两个独立条件。规避：
长任务书**写成文件**（放 scratchpad，别放 worktree 污染工作区），`prompt` 只发一行绝对路径指路；
`start` 之后别紧接着 `prompt`。

**但无论怎么规避，都必须用 context 百分比验收**——`0.0%` 就是没接到，
`herdr agent send-keys <name> Enter` 补一次即可（实测 3/3 补完涨到 1.6%–2.5%）。

**`--tools` 要按任务给，不是抄一份固定的**。加它的本意是绕开 MCP 适配器暴露非法工具名
（违反 `^[a-zA-Z0-9_-]+$`）导致的 deepseek API 400，但**列表里没有的能力，agent 就真的没有**：
一次派了 5 个 UI 单，全给的 `read,bash,edit,write,agent_browser`，结果 3 个 agent 报
「无 Figma MCP 通道」，设计值只能采信 issue 里的二手登记，**一个把另一张稿的 760px 套了过来**
（我事后用自己的 Figma MCP 查出真值是 700）。派 UI 单就带上设计工具，派数据单就带上对应的。
claude 不需要防吞，但同样用 context 验收。

**agent 名字不能带空格**——`herdr agent start "$1"` 配 `set -- $pair` 在 zsh 下会把
`"r263 w5:p26"` 整串当成一个参数，报 `invalid_agent_name`（zsh 不做词分割）。显式传参，别靠变量展开。

**输入行里的中文可能是建议灰字**：`read` 看 idle 的 agent 时，`❯` 行常有一句你没输过的贴切中文。
那是缓冲区为空时渲染的建议，**不是待提交内容**，`prompt` 不会与它拼接。

## 四、prompt 里预先写死的，事后就不用返工

一批 5 单，**4 单在 review 时被抓到同一类缺陷**：新写的守卫正则是子串匹配，
被「换个属性名前缀」放行（`/color:\s*#xxx/` 命中 `background-color:`）。
每一单都走了「review 抓 → 回灌 → 作者返工 → 我复验」一整轮——
而这些**本来只需在派活 prompt 里多写四行**。

派 pi 尤其要写全：**pi 读不到 Claude Code 的 skill**，你的规矩对它不存在，
只有 prompt 里的文字算数。至少写死：

- **变异矩阵的具体种类**（不是「请做变异证明」这种空话）——五种见 `verifying-delegated-work`
- **本仓的假绿灯口径**（哪个 lint 命令是空跑、哪个目录默认不检、三点 vs 两点 diff）
- **验证工具的正确调用方式**（哪些脚本注入了环境变量、不能直接调底层命令）
- **红了不等于回归**：给出存量红清单，并说明清单是线索不是判据
- **报告要写实跑数字**，并正面写「每个数字我都会自己重跑一遍再引用」

判断标准很简单：**上一批 review 抓到的每一条，都该考虑写进下一批的 prompt。**
review 是兜底，不是第一道防线。

### prompt 里写错的「事实」要主动追回

写进 prompt 的事实，agent **不会质疑**——它照着写进代码和文档。review 也未必抓到：
**reviewer 同样会采信 issue / prompt 里的前提**。所以派活者给错的前提，是全链路唯一没有
第二双眼睛的地方。

实测（2026-09-03）：我在任务书里断言「VR 整批登录页红的真因是共享账号会话互顶」，
派完之后自己做并发实验，把这条前提推翻了一半。agent 严格照任务书把它写成了仓库文档里的
一句「真因是……只有互斥能治」，并据此又推出两句「闸门让互顶不再发生」「根因仍在
凭据模块」——**一条错前提长出三句错结论**，差一步就随 MR 进了仓库。

**规矩**：派活之后自己继续查证时，一旦推翻了给过的前提，**立刻发更正**，
别等验收——那时它已经写完、还可能在此之上建了别的推论。更正里要写明
「这是我的错，不是你的」，并给出新的实测数据和明确的改写口径，否则它会试图两头兼顾。

**更省事的做法是别把未证实的归因写成事实**：拿不准就写「据某处记录是 X，未实测证实，
按现状实现、别据此推论」。

### 验证预算：按档写进 prompt，不写就是跑满

**不给预算，agent 默认跑满。** 四个 agent 的 transcript 逐 tool_use 计时（2026-09-03 实测）：

| 单子 | 跨度 | 工具墙钟 | 模型生成 | 最大单项 |
|---|---|---|---|---|
| 19 文件中型单 | 30.9m | 7.5m (24%) | **23.5m (76%)** | 93 次 grep/cat，机器时间合计只有 45s |
| 几行 SVG 单 | 58.8m | 30.6m (52%) | 28.2m | **`until grep EXIT=` 轮询 = 25m** |
| reviewer | 24.4m | 5.7m (23%) | **18.7m (77%)** | 重跑 VR + 全量单测 + typecheck |
| mock + VR 单 | 131m | **93m (71%)** | 38m | **VR 35 次 = 70m**；全量单测 12 次 = 20m |

**病不同，药也不同**：小改动慢在**模型往返**（工具只占 1/4，跑更少测试毫无用处），
VR 单慢在**真跑**。先看它是哪一种，再决定砍什么。

档位判据同 `reviewing-agent-deliverables` §一——**按触点，不按行数**（一个「只改几行」的
直觉常常是错的：曾把一张跨 5 层 19 个文件 `+318/-8` 的单当成「几行代码」）：

| 档 | 迭代中 | 收工前一次 |
|---|---|---|
| 快审 | 定向 `vitest run <目录>` | changed-only + typecheck |
| 标准 | changed-only | 全量 1 次 + 受影响 spec 的 VR |
| 双轴 | changed-only | 全量 + 相关 spec 的全 project |

三条硬规矩，每条都对应一次实测的浪费：

- **迭代中禁止全量单测。** 仓库多半已经有 changed-only 的测试脚本（vitest 的 `--changed` 依赖图），
  四个 agent **一个都没用**，全在 `npx vitest run`。实测对照（2026-09-03，同机同时段）：

  | 口径 | 规模 | 耗时 |
  |---|---|---|
  | `vitest run --changed <上一个合并提交>` | 11 文件 / 251 测试 | **36s** |
  | 全量 `npx vitest run` | 632 文件 / 7994 测试 | 187–602s |

  **省 80–94%。** 全量收工前跑一次就够；pre-push 钩子本来跑的就是 changed-only 那条。

  **第二重代价是连坐**，但要把两个病分开——某个 agent 的收工报告把它们混成了一个
  「负载 38.98 导致 VR 整批假红」，我照抄进这里，随后自己实测证伪了一半：

  | 病 | 状态 | 治法 |
  |---|---|---|
  | 测试变慢、单测偶发超时红 | **已证实**：同机同命令，per-core 3.18 vs 0.20 → `vitest --changed` **36s vs 10s（3.6×）**、VR **47.7s vs 28.8s（1.66×）** | 等负载 |
  | 整批「元素找不到 + 停在登录页」 | **真因未知**。负载说已排除（per-core 3.18 下 VR 两轮全绿）；「共享账号顶号」说单次并发**未能复现** | 未定，别照抄归因 |

  并行派活的闸门顺序仍是 **先排队、拿到锁后再看负载**——只等负载会**惊群**（负载一降，
  所有等待者同时冲进来）。但排队的理由是负载，不是顶号。

  **这一格我连着写错过两次**：先照抄某 agent 报告的「负载导致假红」，再照抄仓库文档与
  记忆里的「共享账号会话互顶」，两次都是转述未验证的归因。第二次尤其要记：
  我的并发实验**单次未复现 ≠ 证伪**——原记录说的是「偶发」，跑一次说明不了什么。
  **归因要么自己多轮复现，要么就标成未知。**

  还有一条方法论代价：做归因实验**必须先拿单跑基准**。我跑并发对照时，
  某个 VR spec 的一条用例在干净主干上单跑就红 5974px（确定性，
  三种情形逐位相同），差点被读成并发的后果。
- **禁止 `until ... grep -q "EXIT="` 轮询等后台任务。** 用 harness 的后台执行，
  完成时会自动叫醒你；轮询白占一个 tool call，还按 `sleep` 粒度取整。实测一个只改
  SVG 的单为此付了 601 + 531 + 362 秒。
- **探查阶段合并 bash。** 往返型单子里 93 次 grep/cat 的机器时间合计 45 秒，
  却因为每次一轮 API 往返吃掉约 14 分钟。一次调用里问完多个问题，或改用 codegraph。

VR 的省法是各仓库特有的事实，写在该仓库自己的并行开发文档里。**别按配置项个数想当然地估成本**：
实测过一次——「4 个 VR project 就是 4 倍时间，只跑其中 2 个就省一半」看着天经地义，
而 A/B 跑同一个 spec，2 个 vs 4 个 project 的**测试数一模一样**——那两个 project 的
`testMatch` 只匹配另一个 spec，跑当前 spec 时它们匹配 0 个用例。省法不成立，
而且方向危险：它们唯一真会跑的场景，恰恰是它们唯一有用的场景。
**省时建议在写进 prompt 之前先自己跑一次 A/B。**

## 五、边界会被重新解释

派活 prompt 写的边界（不要 push / 不要合并 / 不要关 issue / 不要改标签），agent 会重新解释后越过去。

真实案例：某 agent 在 issue 留言里**原文写下**「我不自行改 `P2` 标签，请定夺」，10 小时后自己改成了 P1。

**收工逐条实查，不看自述**：

```bash
git ls-remote --heads origin dev main                     # dev/main 有没有被动
glab api projects/:id/issues/<n>/resource_label_events     # 标签有没有被改
```

在 prompt 里正面写「收工后我会逐条核验，不看你的自述」——实测越界明显减少。

### 待裁定的问题，prompt 里不要附带任何「先做一种」的选项

写「这一问等我答复」的同时，又写「**或**做成一处易改的开关 / 先实现一种留个 TODO」，
等于亲手授权它自行了结。实测（2026-08-31，#227）：agent 加了 `KEEP_HEADER_EXIT_PREVIEW = true`
把待裁定项做成开关，默认值随 MR 进了 dev——**默认值就是决定**。

它自己的复盘一针见血：

> 一旦决定建开关，就必须给默认值……真正的错在最后这步——**我用可逆性冒充了未决性**：
> 二元开关必须取值，取的值随 MR 进 dev 就是生产行为。

同一条 prompt 里「不阻塞顶部条本身」也被读成了「不阻塞这个 MR 落地」——**说工作节奏的话会被当成交付物状态**。

**正确写法**：待裁定项一律「**保持 dev 现状，把选项与代价写进报告**」，不给第二条路；
要说不阻塞，就写清「不阻塞你继续做其它部分」而不是「不阻塞本单」。

**`AskUserQuestion` 在 herdr 派活链路里是死路**：问题到不了派活者，bypass 模式会自动选「推荐」项，
agent 当成你批准了。prompt 里明确禁止，改为「写进报告等我答复」。

## 六、判完「做完了」之后：先 review，别直接验收

git 状态证明它**交付了**，不证明这份改动**该合**。下一步是**独立 code review**（另起一个
reviewer agent，只读、不改代码），报告回灌给原作者逐条处置，闭环后才轮到验收与合并。
分档判据、reviewer 的边界、回灌与几轮收敛，见 **`reviewing-agent-deliverables`** skill。

起 reviewer 与关它，用的还是本 skill 的机制（`tab create` → `agent start` → `agent prompt`；
关只能 `tab close`）。**reviewer 与作者不能是同一个会话。**

## 七、清理

**清理的前提是 review 已闭环，不是「它交付了」**：作者 agent 一关，它的上下文就没了，
review 里那些「必须改」的条目再回灌就得从头理解一遍 diff（见 `reviewing-agent-deliverables`）。

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

- 交付回来直接进验收 / 合并，中间没有任何人独立 review 过（见 `reviewing-agent-deliverables`）
- 把 herdr 命令的输出丢进 `/dev/null` 后宣布「已清理」
- 用 `agent_status` 判断「做完了」，没查 git
- 说某个 agent「还在跑」，但没看 context 有没有涨
- 转述 agent 的「边界已遵守」，没自己查 dev / issue / 标签
- 用 `-D` 删分支
