---
name: woodpecker-ci-triage
description: 在代码提交或推送后检查 Woodpecker CI 流水线状态，失败时自动拉取失败 step 日志并定位根因。当用户说"看看 CI 怎么样了"、"检查一下构建状态"、"为什么 CI 失败了"、或者刚 push 完需要确认 CI 结果时使用。
---

# Woodpecker CI Triage

## 触发场景
- 用户刚 push 代码，想知道 CI 是否通过
- 用户说"看看 CI"、"检查构建状态"、"分析失败日志"
- 需要定位 Woodpecker pipeline 失败的具体 step 和错误点

## 前置信息
- Woodpecker Server: 优先尝试 `https://c6.shafayouxi.org/`，若不可用再尝试 `https://c5.shafayouxi.org/`
- Token: 从环境变量 `WOODPECKER_TOKEN` 读取
- Repo: 自动通过 `git remote -v` 解析 `owner/repo`
- Branch/Commit: 自动通过 `git` 命令读取当前分支和 HEAD

## 工作流

### 1. 等待流水线稳定
如果用户刚 push，先等待 60~120 秒再查询。如果用户明确说"已经等了很久"，可直接查询。

### 2. 查询 Pipeline 状态
使用 `scripts/woodpecker_triage.py` 查询当前分支最新 pipeline：

```bash
export WOODPECKER_SERVER="https://c6.shafayouxi.org/"
export WOODPECKER_TOKEN="$WOODPECKER_TOKEN"
export WOODPECKER_REPO="$(git remote -v | grep fetch | awk '{print $2}' | sed 's/.*://;s/\.git$//' | head -1)"
python3 ~/.claude/skills/woodpecker-ci-triage/scripts/woodpecker_triage.py \
  --wait-seconds 90 \
  --max-wait-seconds 300
```

### 3. 结果处理
- **Success**: 告知用户 CI 已通过，无需进一步操作。
- **Failure / Error / Canceled / Killed**: 脚本会输出失败 step 名称和日志。提取日志中的第一个可执行错误点（如编译错误、测试断言失败、依赖下载超时、脚本退出码非零等），告诉用户根因。
- **Pending / Running**: 告知用户仍在运行，建议再等待。
- **No pipeline found**: 检查全局 Branch Filter 或 Webhook 状态。

### 4. 日志分析原则
- 优先看真正的构建/测试失败，忽略 cache miss 等噪音。
- 如果日志最后停在网络/鉴权/依赖错误，先修这个再看测试断言。
- 如果 Woodpecker 和 GitHub 状态不一致，以 Woodpecker 日志为准。

## 辅助脚本
- `scripts/woodpecker_triage.py`: 自动查询 repo_id → 列出 pipelines → 匹配 commit → 拉取失败 step 日志。
- `references/woodpecker-api.md`: Woodpecker API 端点和字段说明，用于需要手动调试时参考。

## 常见失败模式速查
| 现象 | 可能原因 |
|------|----------|
| 连单元测试都没触发 | Woodpecker 全局 Branch Filter 拦截 或 GitHub Webhook 被暂停 |
| yarn install 阶段失败 | `react-native-webrtc` 下载超时、GitHub 网络问题、镜像不可用 |
| xcodebuild 日志中断且无错误 | CI Job Timeout，构建超过 runner 最大执行时间 |
| pod install 失败 | CocoaPods specs 未更新、网络问题、本地 podspec 补丁冲突 |
