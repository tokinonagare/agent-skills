---
name: woodpecker-ci-triage
description: 检查 Woodpecker CI 状态并在失败时抓取日志定位根因。适用于代码提交后、Push 后或需要确认构建状态的场景。
---

# Woodpecker CI 故障诊断专家 (Triage Expert)

本技能用于在代码提交、推送或 PR 更新后，自动或手动检查 Woodpecker CI 流水线状态。如果流水线失败，它将定位失败的步骤，抓取并分析日志，帮助快速定位代码或配置问题。

## 核心能力
- **自动检测**: 通过 Git 远程地址和当前分支自动识别仓库与流水线。
- **状态追踪**: 智能等待流水线完成初始化（通常需 60-120 秒）。
- **根因分析**: 仅拉取失败步骤的日志，提取第一个可执行错误点。
- **模型无关**: 统一的指令集，适用于 Gemini, Claude, OpenAI, Kimi 等多种模型。

## 环境变量配置
为确保脚本正常运行，请设置以下环境变量（或在提示中指明）：
- `WOODPECKER_SERVER`: 服务器地址（例如 `https://c6.shafayouxi.org/` 或 `https://ci.woodpecker-ci.org/`）。
- `WOODPECKER_TOKEN`: 个人访问令牌（Personal Access Token）。

## 工作流程 (Workflow)

### 1. 触发与准备
当用户询问 "CI 怎么样了"、"检查构建状态" 或刚完成 `git push` 时触发。
- **获取上下文**: 使用 `git remote -v` 获取 `owner/repo`，使用 `git rev-parse --abbrev-ref HEAD` 获取当前分支。
- **检查稳定性**: 如果刚推送代码，建议等待 60-120 秒。

### 2. 执行诊断脚本
使用内置脚本进行自动化查询：
```bash
python3 scripts/woodpecker_triage.py \
  --repo "owner/repo" \
  --branch "current-branch" \
  --wait-seconds 60
```

### 3. 结果处理逻辑
- **✅ Success**: 告知用户 CI 已通过。
- **❌ Failure / Error**:
    - 脚本将输出失败步骤名称和关键日志段。
    - **分析原则**: 优先处理真正的构建/测试失败，忽略缓存挂载、依赖安装噪音（除非它们是导致失败的原因）。
    - **定位错误**: 寻找第一个 Non-zero exit code 或 Exception 栈信息。
- **⏳ Pending / Running**: 建议用户稍等片刻，或使用 `--wait-seconds` 参数继续追踪。
- 如果本次排查对应某个 PR，最终结论要回发到对应 PR。

## 常见失败模式速查表

| 故障现象 | 可能原因 | 修复建议 |
| :--- | :--- | :--- |
| **Pipeline 未触发** | 分支过滤(Branch Filter)拦截、Webhook 暂停、未配置 CI 文件 | 检查 `.woodpecker/` 配置及仓库 Settings |
| **依赖安装阶段超时** | 网络波动、镜像不可用、资源包体积过大 | 检查网络连通性，尝试使用本地缓存或备用镜像 |
| **编译/测试失败** | 语法错误、逻辑 Bug、断言失败 | 根据日志定位代码行，优先修复最明显的错误点 |
| **权限/认证错误** | Token 过期、密钥(Secrets)配置错误 | 更新 `WOODPECKER_TOKEN` 或检查 Woodpecker 密钥设置 |

## 辅助资源
- **脚本路径**: `scripts/woodpecker_triage.py`
- **参考文档**: `references/woodpecker-api.md` (包含 API 细节说明)
