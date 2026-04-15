# 智慧编码 Skill

基于 Claude Code 的完整自动化开发流程，从需求到 PR 合并的全过程自动化。

## ✨ 功能特性

- 🤖 **全自动开发**：从需求文档自动生成代码
- 🌿 **智能分支管理**：自动创建功能分支并记录
- 📤 **自动 PR 创建**：智能生成 PR 描述和标题
- 🔍 **持续自动监控**：无限循环监控 PR，直到合并/关闭或手动暂停
- ⚔️ **冲突自动解决**：发现代码冲突立即分析并自动合并
- 🔄 **CI 自动修复**：检测到失败立即分析并修复
- 💬 **评论自动处理**：监控 PR 评论并自动响应修改
- 📝 **完整日志记录**：详细记录每一步操作和修改
- ⏸️ **灵活控制**：随时暂停/恢复监控
- 🔄 **智能恢复**：会话中断后可以恢复继续

## 📦 快速开始

### 0. 前置要求

在使用本 Skill 前，请确保已安装以下工具：

```bash
# 检查 Git
git --version  # 需要 Git 2.x+

# 检查 GitHub CLI
gh --version   # 需要 gh 2.x+，并完成认证（gh auth login）

# 检查 jq（JSON 处理工具）
jq --version   # 需要 jq 1.5+
```

如果缺少工具，请先安装：

```bash
# macOS
brew install gh jq

# Ubuntu/Debian
sudo apt install gh jq

# 其他系统请参考官方文档
```

### 1. 安装 Skill

```bash
# 替换为你的 auto_coding 项目路径
cd $HOME/path/to/auto_coding/skills/智慧编码
./install.sh
```

### 2. 初始化项目

在你的项目根目录运行初始化脚本：

```bash
cd /path/to/your/project
$HOME/path/to/auto_coding/skills/智慧编码/init-project.sh
```

或者创建符号链接方便使用（推荐）：

```bash
# 创建符号链接（替换为你的实际路径）
ln -s $HOME/path/to/auto_coding/skills/智慧编码/init-project.sh /usr/local/bin/init-wisdom-coding

# 然后在任何项目中都可以直接使用：
cd /path/to/your/project
init-wisdom-coding
```

初始化脚本会：
- 在项目根目录创建 `DEVELOPMENT` 文件夹
- 复制 `config.json` 和 `requirements.md` 模板
- 提示是否添加到 `.gitignore`

### 3. 配置

#### 3.1 编辑配置文件

```bash
vim DEVELOPMENT/config.json
```

配置示例：

```json
{
  "git": {
    "main_branch": "master"
  },
  "ci": {
    "check_interval": 30,
    "max_retry": 10
  },
  "pr": {
    "monitor_interval": 60,
    "auto_fix_on_comment": true
  }
}
```

**配置说明**：
- `git.main_branch`: 主分支名称（改为 `master` 或 `main`）
- `ci.check_interval`: CI 检查间隔（秒）
- `ci.max_retry`: 最大重试次数
- `pr.monitor_interval`: 评论监控间隔（秒）
- `pr.auto_fix_on_comment`: 是否自动处理评论

#### 3.2 编辑需求文件

```bash
vim DEVELOPMENT/requirements.md
```

在 "功能需求" 部分填写你要开发的功能：

```markdown
## 功能需求

### 需求描述

**功能目标**: 实现用户登录功能

**用户故事**:
作为用户，我希望能够使用邮箱和密码登录系统

**验收标准**:
1. 用户可以输入邮箱和密码
2. 验证邮箱格式
3. 密码长度至少 8 位
4. 登录成功后跳转到首页
5. 登录失败显示错误提示
```

### 4. 使用 Skill

在项目根目录下启动 Claude：

```bash
cd /path/to/your/project
claude "开始智慧编码"
```

## 📂 目录结构

### Skill 目录

```
skills/智慧编码/
├── SKILL.md                    # Skill 定义（核心文件）
├── README.md                   # 本文件
├── install.sh                  # 安装到 ~/.claude/skills/
├── init-project.sh             # 初始化项目
├── config.example.json         # 配置文件模板
├── requirements.example.md     # 需求文件模板
└── .gitignore                  # Git 忽略配置
```

### 项目目录（初始化后）

```
your-project/
├── DEVELOPMENT/                # 智慧编码工作目录
│   ├── config.json            # 项目配置
│   └── requirements.md        # 需求文档
├── .gitignore                 # 建议添加 DEVELOPMENT/
└── （其他项目文件）
```

**重要**：
- `DEVELOPMENT` 目录在**项目根目录**，不是在 Skill 目录
- 每个项目有自己的 `DEVELOPMENT` 目录
- 建议将 `DEVELOPMENT` 加入 `.gitignore`（如果包含敏感信息）

## 🔄 完整工作流程（4 个阶段）

```
阶段 0: Plan（规划）
   │
   ├─→ 理解用户需求
   ├─→ 分解任务列表
   ├─→ 制定技术方案
   └─→ 用户确认 ✅
       │
       ↓
阶段 1: 初始化
   │
   ├─→ 创建功能分支
   ├─→ 创建 DEVELOPMENT/
   ├─→ 生成 config.json（记录分支信息）
   └─→ 生成 requirements.md（记录任务计划）
       │
       ↓
阶段 2: 开发
   │
   ├─→ 开发代码
   ├─→ 编写测试
   ├─→ 提交代码
   ├─→ 创建 PR
   └─→ 记录 PR 信息
       │
       ↓
阶段 3: 持续监控和修复 🔄
   │
   ├─→ 【无限循环】持续监控 PR
   │   │
   │   ├─→ 每 60 秒检查一次：
   │   │   ├─ PR 状态（MERGED/CLOSED → 结束）
   │   │   ├─ 代码冲突（有 → 自动解决）
   │   │   ├─ CI 检查（失败 → 自动修复）
   │   │   ├─ 新评论（有 → 自动处理）
   │   │   └─ 审查状态（显示进度）
   │   │
   │   └─→ 用户可随时：
   │       ├─ 说"暂停监控" → 停止循环
   │       └─ 说"继续监控" → 恢复循环
   │
   └─→ PR 合并或关闭 → 自动结束
       │
       ↓
阶段 4: 清理
   │
   ├─→ 确认 CI 全部通过
   ├─→ 确认 Review 已批准
   ├─→ 删除 DEVELOPMENT/
   └─→ 完成 🎉
```

### 关键特点

- **Plan 优先**：开始前先与用户确认计划
- **自动初始化**：自动创建分支和配置文件
- **持续自动监控**：无限循环监控，直到 PR 合并/关闭或手动暂停
- **灵活控制**：随时暂停/恢复监控
- **自动清理**：完成后自动删除工作目录

## 🚀 使用示例

### 示例 1：完整流程（推荐）

```bash
# 在项目目录
cd ~/my-project

# 启动智慧编码
claude "开始智慧编码"

# 或者更明确地说明需求：
claude "帮我实现用户登录功能"
```

**Claude 会自动执行 4 个阶段**：

```
阶段 0: Plan
  Claude: "我将帮您实现用户登录功能。

  我的理解：
  1. 创建登录表单（用户名 + 密码）
  2. 实现登录 API 端点
  3. 添加 JWT 认证
  4. 编写单元测试

  请确认这个计划是否正确？"

  你：确认或调整 ✅

阶段 1: 初始化
  ✅ 创建分支: feature-user-login
  ✅ 创建 DEVELOPMENT/
  ✅ 生成 config.json 和 requirements.md

阶段 2: 开发
  ✅ 开发登录表单组件
  ✅ 实现 API 端点
  ✅ 添加认证逻辑
  ✅ 编写测试
  ✅ 创建 PR

阶段 3: 持续监控
  🔍 开始持续监控 PR #123...
  ⚠️  监控将持续运行，直到 PR 合并/关闭或您手动暂停

  📊 监控周期 #1
  ✅ CI 检查通过
  💬 暂无新评论
  ⏳ 等待代码审查

  📊 监控周期 #2
  💬 发现新评论！处理中...
  ✅ 已修复并回复

  ...（持续监控中）

  你：暂停监控

  ✅ 已暂停监控（可随时说"继续监控"恢复）

阶段 4: 清理
  ✅ 删除 DEVELOPMENT/
  🎉 完成！
```

### 示例 2：从现有项目开始（需要初始化）

```bash
# 如果项目从未使用过智慧编码
cd ~/old-project

# 方式 1：使用初始化脚本
init-wisdom-coding

# 方式 2：让 Claude 自动处理
claude "开始智慧编码"
# Claude 会检测到没有 DEVELOPMENT，自动创建
```

### 示例 2：在多个项目中使用

```bash
# 项目 A
cd ~/project-a
init-wisdom-coding
# 编辑 DEVELOPMENT/requirements.md
claude "开始智慧编码"

# 项目 B
cd ~/project-b
init-wisdom-coding
# 编辑 DEVELOPMENT/requirements.md
claude "开始智慧编码"
```

每个项目都有独立的配置和需求文件。

### 示例 3：监控控制

持续监控功能支持灵活的控制：

```bash
# 开始监控（PR 创建后自动开始）
claude "开始智慧编码"
# → 自动创建 PR 并进入持续监控

# 监控过程中...
🔍 监控周期 #5
📌 PR 状态: OPEN
✅ CI 检查通过
💬 暂无新评论
⏳ 等待代码审查
💡 提示：您可以随时说'暂停监控'来停止

# 暂停监控
claude "暂停监控"
# → 立即停止监控循环，保留所有状态

# 稍后恢复监控
claude "继续监控"
# → 从上次暂停的地方继续

# 查看状态（不启动监控）
claude "检查智慧编码状态"
# → 显示当前 PR 状态，但不进入持续监控循环
```

**监控控制命令**：
- **暂停**："暂停监控" / "停止智慧编码" / "暂停自动监控"
- **恢复**："继续监控" / "继续智慧编码" / "恢复监控 PR"
- **查看**："监控状态" / "检查智慧编码状态" / "PR 状态如何"

### 示例 4：恢复中断的流程

```bash
# 如果会话中断，重新启动：
cd ~/my-project
claude "继续智慧编码"

# Claude 会：
# 1. 读取 DEVELOPMENT/requirements.md 获取状态
# 2. 提取分支名和 PR 号
# 3. 检查当前 CI 状态
# 4. 继续监控或修复流程
```

## ⚙️ 配置说明

### config.json 完整说明

```json
{
  "git": {
    "main_branch": "master"
  },
  "ci": {
    "check_interval": 30,
    "max_retry": 10
  },
  "pr": {
    "monitor_interval": 60,
    "auto_fix_on_comment": true
  }
}
```

**字段说明**：

- `git.main_branch`：主分支名称，根据项目实际情况改为 `master` 或 `main`
- `ci.check_interval`：CI 检查间隔（秒），建议 30-60 秒
- `ci.max_retry`：最大重试次数，避免无限循环
- `pr.monitor_interval`：PR 评论监控间隔（秒），建议 60-120 秒
- `pr.auto_fix_on_comment`：是否自动处理评论，建议开启

### requirements.md 结构

```markdown
# 开发需求

## ⚠️ 重要：AI 必须遵守的规则
（AI 必须记录分支名和 PR 链接）

## 分支信息
- **分支名称**: `[AI 填写]`
- **创建时间**: `[AI 填写]`
- **PR 链接**: `[AI 填写]`
- **PR 状态**: `[AI 填写]`

## 功能需求
（用户填写具体功能需求）

## 技术要求
（技术规范检查清单）

## 开发日志
（AI 记录每次修改）

## PR 评论处理记录
（AI 记录评论处理过程）
```

## 🎯 触发方式

### 开始新的开发流程

- `"开始智慧编码"`
- `"执行自动开发"`
- `"自动实现需求"`

### 继续中断的流程

- `"继续智慧编码"`
- `"检查智慧编码状态"`
- `"恢复自动开发流程"`

### 处理特定问题

- `"CI 失败了，自动修复"`
- `"处理 PR 评论反馈"`

## ⚠️ 重要注意事项

### 1. DEVELOPMENT 目录位置

- ✅ **正确**：`/your-project/DEVELOPMENT/`（项目根目录）
- ❌ **错误**：`skills/智慧编码/DEVELOPMENT/`（Skill 目录）

### 2. 配置文件位置

- ✅ **正确**：`/your-project/DEVELOPMENT/config.json`
- ❌ **错误**：`skills/智慧编码/config.json`

### 3. 长时间运行

- 监控 CI 和评论需要保持 Claude 会话开启
- 如果中断，使用 "继续智慧编码" 恢复

### 4. .gitignore 配置

建议将 DEVELOPMENT 目录加入 `.gitignore`：

```gitignore
# 智慧编码配置和需求文件
DEVELOPMENT/
```

如果需要版本控制管理，可以只忽略敏感信息：

```gitignore
# 只忽略实际配置
DEVELOPMENT/config.json
DEVELOPMENT/requirements.md

# 保留模板（可选）
!DEVELOPMENT/*.example.*
```

## 🔧 故障排查

### Skill 未触发

```bash
# 检查 Skill 是否正确安装
ls -la ~/.claude/skills/智慧编码
```

### DEVELOPMENT 目录未找到

```bash
# 检查当前目录
pwd
git rev-parse --show-toplevel

# 确保在项目根目录
cd $(git rev-parse --show-toplevel)

# 重新初始化
init-wisdom-coding
```

### 配置文件未找到

```bash
# 检查 DEVELOPMENT 目录
ls -la DEVELOPMENT/

# 如果不存在，重新初始化
init-wisdom-coding
```

### CI 监控不工作

```bash
# 检查 GitHub CLI
gh auth status

# 检查 PR 信息
gh pr view <pr-number>
```

## 💡 最佳实践

### 1. 项目初始化

每个新项目第一次使用时：
```bash
cd /path/to/new/project
init-wisdom-coding
vim DEVELOPMENT/config.json      # 配置项目设置
vim DEVELOPMENT/requirements.md  # 填写需求
claude "开始智慧编码"
```

### 2. 需求描述要清晰

在 `DEVELOPMENT/requirements.md` 中详细描述：
- 功能目标（要做什么）
- 用户故事（谁要用、为什么要用）
- 验收标准（怎样算完成）
- 技术要求（用什么技术栈）

### 3. 合理配置间隔

- CI 快的项目：`check_interval: 20-30`
- CI 慢的项目：`check_interval: 60-120`
- 评论监控：`monitor_interval: 60-120`

### 4. 版本控制

可以将 DEVELOPMENT 目录纳入版本控制：
```bash
# 1. 不忽略整个目录
# 2. 只提交模板文件
git add DEVELOPMENT/*.example.*

# 3. 忽略实际配置
echo "DEVELOPMENT/config.json" >> .gitignore
echo "DEVELOPMENT/requirements.md" >> .gitignore
```

## ✅ 验证安装

为确保 Skill 正确安装和配置，可以按照以下清单进行验证：

### 验证清单

#### 1. 验证 Skill 安装

```bash
# 检查 Skill 是否已安装
ls -la ~/.claude/skills/智慧编码

# 应该看到以下文件：
# - SKILL.md
# - README.md
# - install.sh
# - init-project.sh
# - config.example.json
# - requirements.example.md
# - .gitignore
```

#### 2. 验证项目初始化（交互模式）

```bash
# 在测试项目中运行
cd /path/to/test/project
~/.claude/skills/智慧编码/init-project.sh

# 验证点：
# ✅ 提示"是否覆盖"（如果 DEVELOPMENT 已存在）
# ✅ 提示"是否添加到 .gitignore"
# ✅ 成功创建 DEVELOPMENT/config.json
# ✅ 成功创建 DEVELOPMENT/requirements.md
```

#### 3. 验证项目初始化（非交互模式）

```bash
# 测试非交互模式
cd /path/to/test/project
~/.claude/skills/智慧编码/init-project.sh --yes

# 验证点：
# ✅ 无需手动确认，自动执行所有操作
# ✅ 自动覆盖现有配置文件
# ✅ 自动添加 DEVELOPMENT 到 .gitignore
```

#### 4. 验证覆盖既有配置

```bash
# 创建测试配置
mkdir -p DEVELOPMENT
echo "test" > DEVELOPMENT/config.json

# 运行初始化（交互模式）
~/.claude/skills/智慧编码/init-project.sh

# 验证点：
# ✅ 检测到现有配置
# ✅ 提示是否覆盖
# ✅ 选择"yes"后成功覆盖

# 运行初始化（非交互模式）
~/.claude/skills/智慧编码/init-project.sh --yes

# 验证点：
# ✅ 自动覆盖，无需确认
```

#### 5. 验证 .gitignore 处理

```bash
# 场景 1：.gitignore 存在但未包含 DEVELOPMENT
# 验证点：
# ✅ 交互模式：提示是否添加
# ✅ 非交互模式：自动添加

# 场景 2：.gitignore 不存在
# 验证点：
# ✅ 交互模式：提示是否创建
# ✅ 非交互模式：自动创建并添加 DEVELOPMENT

# 场景 3：.gitignore 已包含 DEVELOPMENT
# 验证点：
# ✅ 显示"DEVELOPMENT 已在 .gitignore 中"
# ✅ 不重复添加
```

#### 6. 验证 Skill 触发

```bash
# 在项目根目录启动 Claude
cd /path/to/project
claude "开始智慧编码"

# 验证点：
# ✅ Skill 成功触发
# ✅ 读取 DEVELOPMENT/config.json
# ✅ 读取 DEVELOPMENT/requirements.md
# ✅ 开始执行工作流程
```

### 快速验证脚本

可以使用以下脚本快速验证安装：

```bash
#!/bin/bash
echo "🔍 验证智慧编码 Skill 安装..."

# 1. 检查 Skill 安装
if [ -d "$HOME/.claude/skills/智慧编码" ]; then
    echo "✅ Skill 已安装"
else
    echo "❌ Skill 未安装"
    exit 1
fi

# 2. 检查必要文件
for file in SKILL.md README.md install.sh init-project.sh config.example.json requirements.example.md; do
    if [ -f "$HOME/.claude/skills/智慧编码/$file" ]; then
        echo "✅ $file 存在"
    else
        echo "❌ $file 缺失"
    fi
done

echo ""
echo "🎉 验证完成！"
```

## 📚 相关文档

- [SKILL.md](./SKILL.md) - Skill 完整定义和工作流程
- [config.example.json](./config.example.json) - 配置文件模板
- [requirements.example.md](./requirements.example.md) - 需求文件模板

## 🆘 获取帮助

如果遇到问题：

1. 查看 `DEVELOPMENT/requirements.md` 的开发日志
2. 检查 Claude 的输出信息
3. 运行 `init-wisdom-coding` 重新初始化
4. 查看 [SKILL.md](./SKILL.md) 了解详细流程

## 📝 快速命令参考

```bash
# 安装 Skill
cd skills/智慧编码 && ./install.sh

# 初始化项目
cd /path/to/project && init-wisdom-coding

# 使用
claude "开始智慧编码"

# 恢复
claude "继续智慧编码"

# 查看状态
cat DEVELOPMENT/requirements.md
```

---

🤖 **智慧编码 Skill** - 让 AI 帮你完成从需求到合并的全流程！
