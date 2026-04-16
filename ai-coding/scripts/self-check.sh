#!/bin/bash
# 阶段 0: 状态自检与恢复 (Self-Check & Resume)

echo "🔍 智慧编码 - 正在执行状态自检..."

# 0.1 检查 Git 状态与清理
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
MAIN_BRANCH=${MAIN_BRANCH:-"master"}

if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
    PR_STATE=$(gh pr view --json state -q '.state' 2>/dev/null)
    if [ "$PR_STATE" = "MERGED" ]; then
        echo "⚠️ 当前分支 $CURRENT_BRANCH 已合并。"
        echo "🔄 自动执行回归操作：切换回 $MAIN_BRANCH 并拉取最新代码..."
        git checkout "$MAIN_BRANCH"
        git pull origin "$MAIN_BRANCH"
        [ -d "DEVELOPMENT" ] && rm -rf "DEVELOPMENT"
        echo "✅ 已回归主分支，准备接受新任务。"
        exit 0
    fi
fi

# 0.2 检查断点恢复
if [ -d "DEVELOPMENT" ] && [ -f "DEVELOPMENT/config.json" ]; then
    echo "✅ 发现进行中的智慧编码任务，正在恢复..."
    
    if [ -f "DEVELOPMENT/requirements.md" ]; then
        echo "📝 发现需求文档，正在读取上下文..."
    fi

    PR_NUMBER=$(jq -r '.pr.number // empty' DEVELOPMENT/config.json)
    
    if [ -n "$PR_NUMBER" ]; then
        echo "📊 状态：阶段 3 (持续监控)。PR #$PR_NUMBER"
        echo "🤖 ACTION: RESUME_MONITOR"
    else
        echo "📊 状态：阶段 2 (开发中)。"
        echo "🤖 ACTION: RESUME_DEVELOP"
    fi
    exit 0
fi

# 0.3 检查隐式任务
if [ ! -d "DEVELOPMENT" ]; then
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠️  发现未提交的代码修改。"
        echo "📂 修改的文件："
        git status --short
        echo "STATUS: IMPLICIT_TASK_DETECTED"
        exit 0
    fi
fi

echo "✅ 状态自检完成，环境纯净，可以开始新任务。"
